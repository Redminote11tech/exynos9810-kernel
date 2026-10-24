#!/usr/bin/env python3
"""Package the built G960F EROFS kernel/DTB with the existing ramdisk-preserving installer."""
import argparse
import hashlib
import json
from pathlib import Path
import struct
import zipfile

ROOT = Path(__file__).resolve().parents[1]


def fdt_properties(blob):
    header = struct.unpack_from('>10I', blob)
    assert header[0] == 0xD00DFEED
    strings = blob[header[3]:header[3] + header[8]]
    pos, stack, properties = header[2], [], {}
    while True:
        token = struct.unpack_from('>I', blob, pos)[0]
        pos += 4
        if token == 1:
            end = blob.index(b'\0', pos)
            stack.append(blob[pos:end].decode())
            pos = (end + 4) & ~3
        elif token == 2:
            stack.pop()
        elif token == 3:
            length, name_offset = struct.unpack_from('>II', blob, pos)
            pos += 8
            name = strings[name_offset:strings.index(b'\0', name_offset)].decode()
            path = '/' + '/'.join(part for part in stack if part)
            properties[(path, name)] = blob[pos:pos + length]
            pos = (pos + length + 3) & ~3
        elif token == 4:
            continue
        elif token == 9:
            return properties
        else:
            raise ValueError(f'Invalid DT token {token}')


def payloads(image):
    data = image.read_bytes()
    assert data[:8] == b'ANDROID!'
    kernel_size, _, ramdisk_size, _, second_size, _, _, page, dt_size, _ = struct.unpack_from('<10I', data, 8)
    align = lambda n: (n + page - 1) // page * page
    assert page in (2048, 4096, 8192, 16384)
    kernel = data[page:page + kernel_size]
    dt_offset = page + align(kernel_size) + align(ramdisk_size) + align(second_size)
    dtb = data[dt_offset:dt_offset + dt_size]
    assert len(kernel) == kernel_size and kernel[56:60] == b'ARM\x64'
    assert b'G960F' in kernel and b'EROFS' in kernel
    assert len(dtb) == dt_size and dtb[:4] == b'DTBH'
    version, count = struct.unpack_from('<II', dtb, 4)
    assert version == 2 and count > 0
    entries = []
    for index in range(count):
        fields = struct.unpack_from('<8I', dtb, 12 + index * 32)
        props = fdt_properties(dtb[fields[5]:fields[5] + fields[6]])
        filesystems = {p: v.rstrip(b'\0').decode() for (p, n), v in props.items()
                       if n == 'type' and any(p.endswith('/fstab/' + part)
                                              for part in ('system', 'vendor', 'odm'))}
        assert len(filesystems) == 3 and set(filesystems.values()) == {'erofs'}, filesystems
        model = props.get(('/', 'model'), b'').rstrip(b'\0').decode()
        assert 'Star rev26' in model, model
        entries.append({'model': model, 'fstab': filesystems})
    return kernel, dtb, entries


def package(image, output):
    kernel, dtb, entries = payloads(image)
    template = ROOT / 'Apollo/kernelzip'
    installer = (template / 'META-INF/com/google/android/update-binary').read_text()
    assert installer.count("if echo $device | grep '[GN]96[05][FN]'; then") == 1
    installer = installer.replace('#!/sbin/sh\n', '#!/sbin/sh\nset -e\n', 1)
    installer = installer.replace('grep "androidboot.bootloader")', 'grep "androidboot.bootloader" || true)', 1)
    installer = installer.replace("if echo $device | grep '[GN]96[05][FN]'; then",
                                  "if echo \"$device\" | grep -q 'G960F'; then", 1)
    installer = installer.replace('boot=$($bb find /dev/block/platform -iname boot)',
                                  'boot=$($bb find /dev/block/platform -iname boot)\n'
                                  '    [ -n "$boot" ] && [ -b "$boot" ] || { ui_print "Boot partition not found"; exit 1; }', 1)
    installer = installer.replace('fkv Installer', 'DS-ACK G960F EROFS test installer')
    installer = installer.replace('Installing DS-ACK-V1 Kernel', 'Installing Enforcing KernelSU Next + SUSFS (EROFS)')
    installer = installer.replace('fkv Installed', 'DS-ACK EROFS test installed')
    with zipfile.ZipFile(output, 'w', compression=zipfile.ZIP_DEFLATED) as archive:
        for path in template.rglob('*'):
            if path.is_file() and path.name != 'update-binary':
                archive.write(path, path.relative_to(template).as_posix())
        info = zipfile.ZipInfo('META-INF/com/google/android/update-binary')
        info.external_attr = 0o100755 << 16
        archive.writestr(info, installer, compress_type=zipfile.ZIP_DEFLATED)
        archive.writestr('floyd/G960F-kernel', kernel)
        archive.writestr('floyd/G960F-dtb', dtb)
    with zipfile.ZipFile(output) as archive:
        assert archive.testzip() is None
    sha = hashlib.sha256(output.read_bytes()).hexdigest()
    output.with_suffix('.zip.sha256').write_text(f'{sha}  {output.name}\n')
    return {'zip': str(output), 'sha256': sha, 'dtbs': entries, 'preserves_rom_ramdisk': True}


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('image', type=Path)
    parser.add_argument('--output', type=Path)
    args = parser.parse_args()
    print(json.dumps(package(args.image, args.output or args.image.with_suffix('.zip')), indent=2))
