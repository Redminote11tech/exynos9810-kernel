"""Run output-seeding logic against real files, without compiling kernels."""
import os
import itertools
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildReuse(unittest.TestCase):
    def test_release_uname_fits_kernel_limit_for_all_variants(self):
        source = (ROOT / 'apollo.sh').read_text()
        function = re.search(r'^BUILD_SET_LOCALVERSION\(\)\s*\n\{.*?^\}', source, re.M | re.S)[0]
        for variant, mode, fs in itertools.product(
                ('G960F', 'G965F', 'N960F', 'G960N', 'G965N', 'N960N'),
                ('1', '2'), ('erofs', 'ext4')):
            result = subprocess.run(['bash', '-c', function + '\nBUILD_SET_LOCALVERSION; printf "%s" "$LOCALVERSION"'],
                                    env={**os.environ, 'CR_NAME': 'DS-ACK', 'CR_VERSION': 'V3.2.2-susfs2',
                                         'CR_VARIANT': variant, 'CR_SELINUX': mode, 'CR_FS_TYPE': fs},
                                    check=True, capture_output=True, text=True)
            self.assertLessEqual(len('4.9.337' + result.stdout), 64)
            self.assertIn(variant, result.stdout)
            self.assertEqual('Permissive' in result.stdout, mode == '1')
            self.assertIn(fs.upper(), result.stdout)

    def test_dtb_cleanup_removes_old_board_blobs_and_preserves_kernel_objects(self):
        source = (ROOT / 'apollo.sh').read_text()
        function = re.search(r'^BUILD_CLEAN_DTBS\(\)\s*\n\{.*?^\}', source, re.M | re.S)[0]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            boot = root / 'arch/arm64/boot'
            dts = boot / 'dts/exynos'
            dts.mkdir(parents=True)
            stale = [boot / 'dtb.img', boot / '.dtb.img.cmd', dts / 'old-board.dtb',
                     dts / '.old-board.dtb.cmd']
            for p in stale: p.write_text('stale')
            keep = [boot / 'Image', dts / 'keep.o', dts / 'board.dts']
            for p in keep: p.write_text('keep')
            subprocess.run(['bash', '-c', function + '\nBUILD_CLEAN_DTBS'], check=True,
                           env={**os.environ, 'CR_OUTDIR': str(root), 'CR_ARCH': 'arm64'})
            self.assertTrue(all(not p.exists() for p in stale))
            self.assertTrue(all(p.read_text() == 'keep' for p in keep))

    def test_parallel_start_requires_a_completed_seed_for_every_model(self):
        source = (ROOT / 'apollo.sh').read_text()
        function = re.search(r'^BUILD_HAS_MODEL_SEEDS\(\)\s*\n\{.*?^\}', source, re.M | re.S)[0]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            variants = ('G960F', 'G965F', 'N960F', 'G960N', 'G965N', 'N960N')
            for index, variant in enumerate(variants):
                seed = root / f'{variant}-enforcing-ksu-erofs'
                seed.mkdir()
                (seed / '.dsack-complete').touch()
                result = subprocess.run(['bash', '-c', function + '\nBUILD_HAS_MODEL_SEEDS'],
                                        env={**os.environ, 'CR_OUT_ROOT': str(root)})
                self.assertEqual(result.returncode == 0, index == len(variants) - 1)

    def test_prefers_same_device_same_mode_across_filesystems(self):
        source = (ROOT / 'apollo.sh').read_text()
        function = re.search(r'^BUILD_SEED_OUTPUT\(\)\s*\n\{.*?^\}', source, re.M | re.S)[0]
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            fallback = root / 'G960F-permissive-ksu-ext4'
            nearest = root / 'G965F-permissive-ksu-erofs'
            target = root / 'G965F-permissive-ksu-ext4'
            for path, data in ((fallback, 'different device'), (nearest, 'same device and mode')):
                path.mkdir()
                (path / '.config').write_text(data)
                (path / '.dsack-complete').touch()
            subprocess.run(['bash', '-c', function + '\nBUILD_SEED_OUTPUT'], check=True,
                           env={**os.environ, 'CR_SEED_OUTPUTS': '1', 'CR_CLEAN': 'n',
                                'CR_OUTDIR': str(target), 'CR_SEED_DIR': str(fallback),
                                'CR_TAG': target.name, 'CR_VARIANT': 'G965F', 'CR_SELINUX': '1',
                                'CR_FS_TYPE': 'ext4', 'CR_OUT_ROOT': str(root)}, capture_output=True)
            self.assertEqual((target / '.config').read_text(), 'same device and mode')

    def test_seed_is_independent_and_requires_completed_source(self):
        source = (ROOT / 'apollo.sh').read_text()
        function = re.search(r'^BUILD_SEED_OUTPUT\(\)\s*\n\{.*?^\}', source, re.M | re.S)[0]
        for complete, clean in ((True, 'n'), (False, 'n'), (True, 'y')):
            with self.subTest(complete=complete, clean=clean), tempfile.TemporaryDirectory() as tmp:
                seed, target = Path(tmp) / 'seed', Path(tmp) / 'target'
                seed.mkdir()
                (seed / 'object.o').write_text('original')
                (seed / '.config').write_text('old configuration')
                if complete:
                    (seed / '.dsack-complete').touch()
                subprocess.run(['bash', '-c', function + '\nBUILD_SEED_OUTPUT'], check=True,
                               env={**os.environ, 'CR_SEED_OUTPUTS': '1', 'CR_CLEAN': clean,
                                    'CR_OUTDIR': str(target), 'CR_SEED_DIR': str(seed), 'CR_TAG': 'test'},
                               capture_output=True)
                if complete and clean == 'n':
                    self.assertEqual((target / 'object.o').read_text(), 'original')
                    self.assertFalse((target / '.dsack-complete').exists())
                    self.assertNotEqual((seed / 'object.o').stat().st_ino,
                                        (target / 'object.o').stat().st_ino)
                    (target / 'object.o').write_text('new variant')
                    self.assertEqual((seed / 'object.o').read_text(), 'original')
                else:
                    self.assertFalse(target.exists())


if __name__ == '__main__':
    unittest.main()
