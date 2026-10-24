#!/usr/bin/env python3
"""Package the Un1ca workaround with the daemon from a trusted Manager APK.

Use the official v3.4.2 APK. The extracted daemon must report UAPI 5 on-device;
the startup hook refuses incompatible daemons. This does not build a kernel.
"""
import argparse
import hashlib
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]
# Official v3.4.2 arm64 daemon, also matched against the installed phone daemon.
DAEMON_SHA256 = '7794fb0546955e10b3b61a2771b325d52e47ac1d4702970c9a46e3b1667db042'


def package(apk, output):
    with zipfile.ZipFile(apk) as source:
        daemon = source.read('lib/arm64-v8a/libksud.so')
    if (daemon[:5] != b'\x7fELF\x02' or struct.unpack_from('<H', daemon, 18)[0] != 183
            or hashlib.sha256(daemon).hexdigest() != DAEMON_SHA256):
        raise ValueError('Expected the official v3.4.2 arm64 UAPI 5 daemon')
    output.parent.mkdir(parents=True, exist_ok=True)
    template = ROOT / 'scripts/un1ca-ksud-compat'
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as target:
        for name, data, mode in [
            ('module.prop', (template / 'module.prop').read_bytes(), 0o644),
            ('post-fs-data.sh', (template / 'post-fs-data.sh').read_bytes(), 0o755),
            ('ksud', daemon, 0o755),
            ('LICENSE', (ROOT / 'KernelSU-Next/LICENSE').read_bytes(), 0o644),
            ('LICENSE.DS-ACK', (ROOT / 'COPYING').read_bytes(), 0o644),
            ('NOTICE', b'KernelSU Next daemon from the official v3.4.2 release.\n'
             b'Corresponding source: https://github.com/KernelSU-Next/KernelSU-Next/tree/v3.4.2\n'
             b'Daemon license: GPL-3.0 (LICENSE). DS-ACK startup hook: GPL-2.0 (LICENSE.DS-ACK).\n', 0o644),
        ]:
            entry = zipfile.ZipInfo(name)
            entry.external_attr = (0o100000 | mode) << 16
            entry.compress_type = zipfile.ZIP_DEFLATED
            target.writestr(entry, data)
    digest = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{digest}  {output.name}\n')
    return digest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('apk', type=Path)
    parser.add_argument('--output', type=Path, default=ROOT / 'Apollo/Product/DS-ACK-Un1ca-ksud-compat-v1.1.zip')
    args = parser.parse_args()
    print(f'{package(args.apk, args.output)}  {args.output}')
