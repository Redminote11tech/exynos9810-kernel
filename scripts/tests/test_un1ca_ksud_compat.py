"""Execute the real startup hook with isolated filesystem and namespace tools."""
import os
from pathlib import Path
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOOK = ROOT / 'scripts/un1ca-ksud-compat/post-fs-data.sh'


class Un1caDaemonCompatTest(unittest.TestCase):
    def run_hook(self, data_uapi=5, kernel_uapi=5, mount_status=0, rom_uapi=4):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            module = root / 'module'
            module.mkdir()
            for path in ['data/adb/ksu/bin', 'system/bin', 'system/etc/init', 'bin']:
                (root / path).mkdir(parents=True)

            def executable(path, contents):
                path.write_text('#!/bin/sh\n' + contents)
                path.chmod(0o755)

            def daemon(path, uapi, label):
                executable(path, f'''case "$1" in
-V) echo 'ksud {label} (uapi: {uapi})';;
debug) echo 'uapi_version: {kernel_uapi}';;
*) exit 1;;
esac
''')

            daemon(module / 'ksud', 5, 'bundled')
            # The real KernelSU installer strips executable archive modes.
            (module / 'ksud').chmod(0o644)
            data = root / 'data/adb/ksud'
            daemon(data, data_uapi, 'manager')
            before = data.read_bytes()
            daemon(root / 'system/bin/ksud', rom_uapi, 'rom')
            (root / 'system/etc/init/unica_ksunext_installer.rc').write_text(
                f'copy {root}/system/bin/ksud {root}/data/adb/ksud\n')
            executable(root / 'bin/chcon', 'exit 0\n')
            executable(root / 'data/adb/ksu/bin/busybox', f'''
echo "$*" >> '{root}/mount.calls'
exit {mount_status}
''')
            # Redirect only absolute device filesystem paths; execute all of the
            # production hook's selection, validation, copy and error handling.
            source = HOOK.read_text().replace('/system/', f'{root}/system/').replace(
                '/data/', f'{root}/data/')
            hook = module / 'post-fs-data.sh'
            hook.write_text(source)
            result = subprocess.run(['sh', str(hook)], env={
                **os.environ, 'PATH': f'{root}/bin:' + os.environ['PATH']})
            calls = root / 'mount.calls'
            return (result.returncode, calls.read_text() if calls.exists() else '',
                    (module / 'ksud').read_text(), data.read_bytes() == before,
                    (module / 'ksud').stat().st_ino != data.stat().st_ino)

    def test_refreshes_compatible_manager_daemon_without_aliasing_live_file(self):
        status, calls, payload, unchanged, separate_inode = self.run_hook()
        self.assertEqual(status, 0)
        self.assertIn('nsenter -t 1 -m --', calls)
        self.assertIn('mount -o bind', calls)
        self.assertIn('ksud manager', payload)
        self.assertTrue(unchanged and separate_inode)

    def test_keeps_known_compatible_payload_when_rom_already_overwrote_data(self):
        status, calls, payload, unchanged, separate_inode = self.run_hook(data_uapi=4)
        self.assertEqual(status, 0)
        self.assertIn('mount -o bind', calls)
        self.assertIn('ksud bundled', payload)
        self.assertTrue(unchanged and separate_inode)

    def test_future_kernel_interface_is_left_alone(self):
        status, calls, payload, unchanged, _ = self.run_hook(kernel_uapi=6)
        self.assertEqual(status, 0)
        self.assertEqual(calls, '')
        self.assertIn('ksud bundled', payload)
        self.assertTrue(unchanged)

    def test_mount_failure_is_reported(self):
        status, calls, _, unchanged, _ = self.run_hook(mount_status=1)
        self.assertEqual(status, 1)
        self.assertIn('mount -o bind', calls)
        self.assertTrue(unchanged)

    def test_repeated_event_does_not_replace_payload_or_stack_mounts(self):
        status, calls, payload, unchanged, _ = self.run_hook(rom_uapi=5)
        self.assertEqual(status, 0)
        self.assertEqual(calls, '')
        self.assertIn('ksud bundled', payload)
        self.assertTrue(unchanged)


if __name__ == '__main__':
    unittest.main()
