#!/usr/bin/env python3
"""Reconstruct every device payload and validate release ZIPs against built outputs."""
import argparse
import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import subprocess
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('s9_package', ROOT / 'scripts/package-s9-erofs-test.py')
s9_package = importlib.util.module_from_spec(spec)
spec.loader.exec_module(s9_package)
VARIANTS = {'G960F': 'Samsung Star rev26', 'G965F': 'Samsung Star2 rev26',
            'N960F': 'Samsung Crown rev0.6', 'G960N': 'Samsung Star rev26',
            'G965N': 'Samsung Star2 rev26', 'N960N': 'Samsung Crown rev0.6'}


def verify(archive, filesystem):
    mode = 'permissive' if '-Permissive-' in archive.name else 'enforcing'
    results = []
    with zipfile.ZipFile(archive) as source, tempfile.TemporaryDirectory() as tmp:
        if source.testzip() is not None:
            raise ValueError('ZIP CRC validation failed')
        installer = source.read('META-INF/com/google/android/update-binary').decode()
        assert 'set -e' in installer and 'Boot partition not found' in installer
        assert 'DS-ACK-V1 Kernel' not in installer and 'fkv' not in installer
        for variant, model in VARIANTS.items():
            output = ROOT / f'out/{variant}-{mode}-ksu-{filesystem}'
            config = (output / '.config').read_text()
            for flag in ('CONFIG_KSU=y', 'CONFIG_KSU_MANUAL_HOOK=y', 'CONFIG_KSU_SUSFS=y'):
                assert flag in config, (variant, flag)
            assert ('CONFIG_ALWAYS_PERMISSIVE=y' in config) == (mode == 'permissive')
            assert ('CONFIG_EXYNOS9810_EROFS_FSTAB=y' in config) == (filesystem == 'erofs')
            hashes = {}
            for kind, filename in (('kernel', 'Image'), ('dtb', 'dtb.img')):
                base = source.read(f'floyd/G960F-{kind}')
                if variant == 'G960F':
                    data = base
                else:
                    old, patch, new = (Path(tmp) / name for name in ('base', 'patch', 'new'))
                    old.write_bytes(base)
                    patch.write_bytes(source.read(f'floyd/{variant}-{kind}'))
                    subprocess.run(['bspatch', str(old), str(new), str(patch)], check=True)
                    data = new.read_bytes()
                assert data == (output / f'arch/arm64/boot/{filename}').read_bytes(), (variant, kind)
                hashes[kind] = hashlib.sha256(data).hexdigest()
                if kind == 'kernel':
                    assert data[56:60] == b'ARM\x64'
                    assert f'-{variant}-'.encode() in data
                    assert (b'-Permissive-' in data) == (mode == 'permissive')
                else:
                    assert data[:4] == b'DTBH'
                    version, count = struct.unpack_from('<II', data, 4)
                    assert version == 2 and count > 0
                    for index in range(count):
                        entry = struct.unpack_from('<8I', data, 12 + 32 * index)
                        props = s9_package.fdt_properties(data[entry[5]:entry[5] + entry[6]])
                        assert props[('/', 'model')].decode().startswith(model)
                        for partition in ('system', 'vendor', 'odm'):
                            assert props[(f'/firmware/android/fstab/{partition}', 'type')] == filesystem.encode() + b'\0'
            results.append({'variant': variant, 'selinux': mode, 'filesystem': filesystem, **hashes})
    digest = hashlib.sha256(archive.read_bytes()).hexdigest()
    archive.with_suffix('.zip.sha256').write_text(f'{digest}  {archive.name}\n')
    return {'archive': archive.name, 'sha256': digest, 'bytes': archive.stat().st_size,
            'payloads': results, 'zip_crc_valid': True, 'all_patches_reconstructed': True,
            'device_tested': False}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('archives', nargs='+', type=Path)
    parser.add_argument('--filesystem', choices=['erofs', 'ext4'], default='erofs')
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    report = [verify(path, args.filesystem) for path in args.archives]
    args.output.write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps(report, indent=2))
