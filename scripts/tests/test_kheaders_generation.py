"""Execute the archive generator and verify header contents and cache reuse."""
import os
from pathlib import Path
import subprocess
import tarfile
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]


class KernelHeaders(unittest.TestCase):
    def test_archive_payload_cache_and_temporary_directory_cleanup(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            src, out, scratch = (root / name for name in ('source', 'output', 'scratch'))
            for base in (src, out):
                (base / 'include').mkdir(parents=True)
                (base / 'arch/arm64/include').mkdir(parents=True)
            scratch.mkdir()
            (out / 'kernel').mkdir()
            (out / 'include/generated').mkdir()
            (src / 'include/test.h').write_text('/* SPDX-License-Identifier: GPL-2.0 */\n/* remove me */\n#define VALUE 7\n')
            (src / 'arch/arm64/include/test.h').write_text('#define ARCH_VALUE 64\n')
            (out / 'include/generated/utsrelease.h').write_text('#define UTS_RELEASE "test"\n')
            env = {**os.environ, 'srctree': str(src), 'SRCARCH': 'arm64',
                   'TMPDIR': str(scratch), 'quiet': 'silent_'}
            command = ['bash', str(ROOT / 'kernel/gen_kheaders.sh'), 'kernel/kheaders_data.tar.xz']
            subprocess.run(command, cwd=out, env=env, check=True)
            archive = out / 'kernel/kheaders_data.tar.xz'
            with tarfile.open(archive) as tar:
                self.assertEqual(tar.extractfile('./include/test.h').read(),
                                 b'/* SPDX-License-Identifier: GPL-2.0 */\n\n#define VALUE 7\n')
                self.assertEqual(tar.extractfile('./arch/arm64/include/test.h').read(), b'#define ARCH_VALUE 64\n')
                self.assertIn(b'UTS_RELEASE', tar.extractfile('./include/generated/utsrelease.h').read())
            self.assertEqual(list(scratch.iterdir()), [])
            stamp = archive.stat().st_mtime_ns
            subprocess.run(command, cwd=out, env=env, check=True)
            self.assertEqual(archive.stat().st_mtime_ns, stamp)
            self.assertEqual(list(scratch.iterdir()), [])


if __name__ == '__main__':
    unittest.main()
