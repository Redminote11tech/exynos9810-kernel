#!/usr/bin/env python3
"""Integration checks with a host C harness; no kernel build or flashing."""
import itertools
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


def run(args, **kwargs):
    return subprocess.run(args, text=True, capture_output=True, check=True, **kwargs)


def shell_function(name):
    source = (ROOT / 'apollo.sh').read_text()
    return re.search(r'^' + name + r'\(\)\s*\n\{.*?^\}', source, re.M | re.S)[0]


class RomCompatibility(unittest.TestCase):
    def test_all_device_fstabs_in_both_filesystem_modes(self):
        # Preprocess sources only; do not run dtc or build any kernel objects.
        makefile = (ROOT / 'scripts/Makefile.lib').read_text()
        self.assertIn('dtc_cpp_flags += -DCONFIG_EXYNOS9810_EROFS_FSTAB', makefile)
        for device, region, filesystem in itertools.product(
                ('starlte', 'star2lte', 'crownlte'), ('eur_open', 'kor'), ('ext4', 'erofs')):
            with self.subTest(device=device, region=region, filesystem=filesystem):
                dts = ROOT / f'arch/arm64/boot/dts/exynos/exynos9810-{device}_{region}_26.dts'
                args = ['cpp', '-P', '-nostdinc', '-undef', '-x', 'assembler-with-cpp']
                if filesystem == 'erofs':
                    args.append('-DCONFIG_EXYNOS9810_EROFS_FSTAB')
                source = run(args + [str(dts)]).stdout
                fstab = source.split('fstab {', 1)[1].split('\n   };', 1)[0]
                types = re.findall(r'\btype\s*=\s*"([^"]+)";', fstab)
                self.assertEqual(types[:3], [filesystem] * 3)
                self.assertEqual(len(types), 3)

    def test_build_matrix_config_and_artifact_separation(self):
        functions = '\n'.join(shell_function(name) for name in (
            'BUILD_TARGET_ID', 'BUILD_IMAGE_NAME', 'BUILD_GENERATE_CONFIG'))
        identities = set()
        for device, mode, filesystem in itertools.product(
                ('G960F', 'G965F', 'N960F', 'G960N', 'G965N', 'N960N'),
                ('0', '1'), ('ext4', 'erofs')):
            with self.subTest(device=device, mode=mode, filesystem=filesystem), tempfile.TemporaryDirectory() as tmp:
                config_dir = Path(tmp)
                # Seed inherited values to check that both branches override them.
                (config_dir / 'base').write_text('CONFIG_EXYNOS9810_EROFS_FSTAB=y\n')
                (config_dir / 'region').touch()
                (config_dir / 'apollo').touch()
                env = dict(os.environ, CR_VARIANT=device, CR_SELINUX=mode,
                           CR_FS_TYPE=filesystem, CR_KSU='y', CR_OUT_ROOT=tmp,
                           CR_ARCH='arm64', CR_DEFCONFIG=tmp, CR_CONFIG='base',
                           CR_CONFIG_SPLIT='NULL', CR_CONFIG_REGION='region',
                           CR_CONFIG_APOLLO='apollo', CR_NAME='DS-ACK',
                           CR_VERSION='test', CR_DATE='test')
                script = functions + '''
BUILD_CLEAN() { :; }
BUILD_TARGET_ID
BUILD_IMAGE_NAME
BUILD_GENERATE_CONFIG >/dev/null
printf '%s\\n' "$CR_TAG" "$CR_IMAGE_NAME" "$zver"
cat "$CR_DEFCONFIG/$CR_TMPCONFIG"
'''
                lines = run(['bash', '-c', script], env=env).stdout.splitlines()
                tag, image, zip_name = lines[:3]
                self.assertNotIn(tag, identities)
                identities.add(tag)
                self.assertEqual('EROFS' in image, filesystem == 'erofs')
                self.assertEqual('EROFS' in zip_name, filesystem == 'erofs')
                config = '\n'.join(lines[3:])
                entries = re.findall(r'^(?:CONFIG_EXYNOS9810_EROFS_FSTAB=y|# CONFIG_EXYNOS9810_EROFS_FSTAB is not set)$', config, re.M)
                self.assertEqual(entries[-1], 'CONFIG_EXYNOS9810_EROFS_FSTAB=y' if filesystem == 'erofs'
                                 else '# CONFIG_EXYNOS9810_EROFS_FSTAB is not set')
                self.assertIn('CONFIG_KSU_MANUAL_HOOK=y', config)
                self.assertEqual('CONFIG_ALWAYS_PERMISSIVE=y' in config, mode == '1')
        self.assertEqual(len(identities), 24)

    def test_submodule_patch_fresh_applied_and_conflicting(self):
        patch = ROOT / 'scripts/ksu-patches/0001-exynos9810-susfs-integration.patch'
        paths = re.findall(r'^diff --git a/(.*?) b/', patch.read_text(), re.M)
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / 'scripts').mkdir()
            (root / 'scripts/ksu-patches').mkdir(parents=True)
            shutil.copy(ROOT / 'scripts/apply-ksu-fixes.sh', root / 'scripts')
            shutil.copy(patch, root / 'scripts/ksu-patches')
            shutil.copy(ROOT / 'scripts/ksu-patches/base-revision', root / 'scripts/ksu-patches')
            run(['git', 'clone', '--shared', '--no-checkout', str(ROOT / 'KernelSU-Next'),
                 str(root / 'KernelSU-Next')])
            revision = (ROOT / 'scripts/ksu-patches/base-revision').read_text().strip()
            run(['git', '-C', str(root / 'KernelSU-Next'), 'checkout', '--detach', revision])
            command = ['bash', str(root / 'scripts/apply-ksu-fixes.sh')]
            run(command)
            first = {path: (root / 'KernelSU-Next' / path).read_bytes() for path in paths}
            run(command)
            self.assertEqual(first, {p: (root / 'KernelSU-Next' / p).read_bytes() for p in paths})
            for path in paths:
                self.assertEqual(first[path], (ROOT / 'KernelSU-Next' / path).read_bytes())
            target = root / 'KernelSU-Next/kernel/runtime/boot_event.c'
            target.write_text(target.read_text().replace('track_throne(false);', 'track_throne(true);'))
            before = target.read_bytes()
            result = subprocess.run(command, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertEqual(before, target.read_bytes())
            (root / 'scripts/ksu-patches/base-revision').write_text('0' * 40 + '\n')
            result = subprocess.run(command, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn('revision mismatch', result.stderr)
            self.assertEqual(before, target.read_bytes())

    def test_real_version_reporting_without_old_spoof(self):
        script = ['bash', str(ROOT / 'scripts/ksu-version.sh')]
        env = dict(os.environ)
        env.pop('KSU_VERSION_OVERRIDE', None)
        self.assertEqual(run(script, env=env).stdout.strip(), '33314')
        env['KSU_VERSION_OVERRIDE'] = '40000'
        self.assertEqual(run(script, env=env).stdout.strip(), '40000')
        self.assertNotIn('KSU_VERSION_OVERRIDE := 33214',
                         (ROOT / 'KernelSU-Next/kernel/Kbuild').read_text())

    def test_setuid_uses_current_upstream_abi_once(self):
        # The obsolete syscall entry hook passed three UIDs to a two-UID ABI
        # and duplicated the LSM hook. Only the latter may call it in manual mode.
        self.assertNotIn('ksu_handle_setresuid', (ROOT / 'kernel/sys.c').read_text())
        self.assertIn('ksu_handle_setresuid(old->uid.val, new_uid.val)',
                      (ROOT / 'KernelSU-Next/kernel/hook/lsm_hooks.c').read_text())
        self.assertIn('security_task_fix_setuid(new, old, LSM_SETID_RES)',
                      (ROOT / 'kernel/sys.c').read_text())
        self.assertNotIn('LSM_HOOK_INIT(inode_rename',
                         (ROOT / 'KernelSU-Next/kernel/hook/lsm_hooks.c').read_text())

    def test_susfs_v2_commands_survive_upstream_update(self):
        definitions = (ROOT / 'include/linux/susfs_def.h').read_text()
        commands = re.findall(r'^#define (CMD_SUSFS_\w+) [^\n]+$', definitions, re.M)
        active = [name for name in commands if 'deprecated' not in
                  re.search(r'^#define ' + name + r' [^\n]+$', definitions, re.M)[0]]
        dispatcher = (ROOT / 'KernelSU-Next/kernel/supercall/supercall.c').read_text()
        self.assertGreater(len(active), 10)
        for name in active:
            self.assertIn('cmd == ' + name, dispatcher)
        self.assertIn('magic2 == SUSFS_MAGIC && current_uid().val == 0', dispatcher)

    def test_file_io_calls_use_legacy_compatibility_wrappers(self):
        root = ROOT / 'KernelSU-Next/kernel'
        for source in root.rglob('*.c'):
            if source == root / 'compat/kernel_compat.c':
                continue
            self.assertIsNone(re.search(r'\bkernel_(?:read|write)\s*\(', source.read_text()),
                              str(source))

    def test_legacy_file_io_argument_order_and_offsets(self):
        source = (ROOT / 'KernelSU-Next/kernel/compat/kernel_compat.c').read_text()
        wrappers = '\n'.join(re.search(r'^ssize_t ' + name + r'\(.*?^}', source, re.M | re.S)[0]
                             for name in ('ksu_kernel_read_compat', 'ksu_kernel_write_compat'))
        for modern in (False, True):
            with self.subTest(backported_api=modern), tempfile.TemporaryDirectory() as tmp:
                code = r'''#include <sys/types.h>
#include <stddef.h>
#include <string.h>
#include <assert.h>
#define loff_t long long
#define KERNEL_VERSION(a,b,c) (((a)<<16)+((b)<<8)+(c))
#define LINUX_VERSION_CODE KERNEL_VERSION(4,9,337)
struct file { char data[16]; int fail; };
'''
                if modern:
                    code += r'''
#define KSU_OPTIONAL_KERNEL_READ
#define KSU_OPTIONAL_KERNEL_WRITE
static ssize_t kernel_read(struct file *f, void *dst, size_t n, loff_t *pos) {
    if (f->fail) return -5;
    memcpy(dst, f->data + *pos, n); *pos += n; return n;
}
static ssize_t kernel_write(struct file *f, const void *src, size_t n, loff_t *pos) {
    if (f->fail) return -5;
    memcpy(f->data + *pos, src, n); *pos += n; return n;
}
'''
                else:
                    code += r'''
static ssize_t kernel_read(struct file *f, loff_t offset, char *dst, unsigned long n) {
    if (f->fail) return -5;
    memcpy(dst, f->data + offset, n); return n;
}
static ssize_t kernel_write(struct file *f, const char *src, size_t n, loff_t offset) {
    if (f->fail) return -5;
    memcpy(f->data + offset, src, n); return n;
}
'''
                code += wrappers + r'''
int main(void) {
    struct file f = { .data = "0123456789", .fail = 0 };
    char out[3] = {0}; loff_t pos = 2;
    assert(ksu_kernel_read_compat(&f, out, 2, &pos) == 2);
    assert(pos == 4 && strcmp(out, "23") == 0);
    assert(ksu_kernel_write_compat(&f, "XY", 2, &pos) == 2);
    assert(pos == 6 && memcmp(f.data + 4, "XY", 2) == 0);
    f.fail = 1;
    assert(ksu_kernel_read_compat(&f, out, 2, &pos) == -5 && pos == 6);
    assert(ksu_kernel_write_compat(&f, "XY", 2, &pos) == -5 && pos == 6);
    return 0;
}
'''
                cfile = Path(tmp) / 'file_io.c'
                executable = Path(tmp) / 'file_io'
                cfile.write_text(code)
                run(['cc', '-std=c11', '-Wall', '-Werror', str(cfile), '-o', str(executable)])
                run([str(executable)])

    def test_driver_uapi_matches_released_manager(self):
        manager = run(['git', '-C', str(ROOT / 'KernelSU-Next'), 'show',
                       'v3.4.2:uapi/supercall.h']).stdout
        driver = (ROOT / 'KernelSU-Next/uapi/supercall.h').read_text()
        def constants(source):
            result = {}
            for line in source.splitlines():
                match = re.match(r'(?:#define |static const \w+ )(\w+)(?: =|) (.*?);?$', line)
                if match:
                    result[match[1]] = re.sub(r'\s+', '', match[2].rstrip(';'))
            return result
        released, current = constants(manager), constants(driver)
        self.assertEqual(current['KERNEL_SU_UAPI_VERSION'], released['KERNEL_SU_UAPI_VERSION'])
        self.assertEqual(current['KERNEL_SU_UAPI_VERSION'], '5')
        self.assertEqual({k: v for k, v in current.items() if k.startswith('KSU_IOCTL_')},
                         {k: v for k, v in released.items() if k.startswith('KSU_IOCTL_')})
        def structs(source):
            source = re.sub(r'/\*.*?\*/|//[^\n]*', '', source, flags=re.S)
            return {name: re.sub(r'\s+', '', body) for name, body in
                    re.findall(r'struct (\w+)\s*{(.*?)};', source, re.S)}
        self.assertEqual(structs(driver), structs(manager))


if __name__ == '__main__':
    unittest.main()
