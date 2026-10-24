"""Run output-seeding logic against real files, without compiling kernels."""
import os
from pathlib import Path
import re
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class BuildReuse(unittest.TestCase):
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
