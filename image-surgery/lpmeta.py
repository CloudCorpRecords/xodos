#!/usr/bin/env python3
"""Minimal lpdump/lpunpack equivalent for an Android super partition inside a GPT raw image.
Implements the documented AOSP liblp metadata format (fs_mgr/liblp metadata_format.h),
validating SHA-256 checksums of geometry, header and tables before trusting any offset.
Read-only: extraction concatenates LINEAR extents exactly as lpunpack would.
"""
import hashlib, json, struct, sys

SECTOR = 512

def parse_gpt(f):
    f.seek(512)
    hdr = f.read(512)
    assert hdr[:8] == b'EFI PART', 'no GPT header'
    part_entry_lba, num_entries, entry_size = struct.unpack_from('<QII', hdr, 72)
    # header fields: rev(8) size(12) crc(16) reserved(20) my_lba(24) alt(32) first_usable(40) last_usable(48) guid(56) part_lba(72) num(80) size(84)
    part_entry_lba = struct.unpack_from('<Q', hdr, 72)[0]
    num_entries = struct.unpack_from('<I', hdr, 80)[0]
    entry_size = struct.unpack_from('<I', hdr, 84)[0]
    parts = []
    for i in range(num_entries):
        f.seek(part_entry_lba * SECTOR + i * entry_size)
        e = f.read(entry_size)
        if e[:16] == b'\x00' * 16:
            continue
        first, last = struct.unpack_from('<QQ', e, 32)
        name = e[56:56 + 72].decode('utf-16-le').rstrip('\x00')
        parts.append({'name': name, 'first_lba': first, 'last_lba': last,
                      'offset': first * SECTOR, 'size': (last - first + 1) * SECTOR})
    return parts

def parse_lp(f, super_off):
    f.seek(super_off + 4096)
    geo = f.read(52)
    magic, struct_size = struct.unpack_from('<II', geo, 0)
    assert magic == 0x616C4467, f'bad geometry magic {magic:#x}'
    meta_max, slot_count, lbs = struct.unpack_from('<III', geo, 40)
    chk = bytearray(geo[:struct_size]); chk[8:40] = b'\x00' * 32
    assert hashlib.sha256(bytes(chk)).digest() == geo[8:40], 'geometry checksum FAIL'
    meta_off = super_off + 12288
    f.seek(meta_off)
    header = f.read(256)
    hmagic, major, minor, header_size = struct.unpack_from('<IHHI', header, 0)
    assert hmagic == 0x414C5030, f'bad header magic {hmagic:#x}'
    hchk = bytearray(header[:header_size]); hchk[12:44] = b'\x00' * 32
    assert hashlib.sha256(bytes(hchk)).digest() == header[12:44], 'header checksum FAIL'
    tables_size = struct.unpack_from('<I', header, 44)[0]
    f.seek(meta_off + header_size)
    tables = f.read(tables_size)
    assert hashlib.sha256(tables).digest() == header[48:80], 'tables checksum FAIL'
    descs = {}
    for i, key in enumerate(['partitions', 'extents', 'groups', 'block_devices']):
        # LpMetadataTableDescriptor order: offset, num_entries, entry_size
        off, cnt, esz = struct.unpack_from('<III', header, 80 + i * 12)
        descs[key] = (off, esz, cnt)
    def entries(key, fmt):
        off, esz, cnt = descs[key]
        out = []
        for i in range(cnt):
            out.append(struct.unpack_from(fmt, tables, off + i * esz))
        return out
    parts = []
    for name_raw, attrs, fei, nec, gi in entries('partitions', '<36sIIII'):
        parts.append({'name': name_raw.split(b'\x00')[0].decode(), 'attributes': attrs,
                      'first_extent_index': fei, 'num_extents': nec, 'group_index': gi})
    exts = []
    for ns, tt, td, ts in entries('extents', '<QIQI'):
        exts.append({'num_sectors': ns, 'target_type': tt, 'target_data': td, 'target_source': ts})
    groups = []
    for name_raw, flags, maxsz in entries('groups', '<36sIQ'):
        groups.append({'name': name_raw.split(b'\x00')[0].decode(), 'flags': flags, 'maximum_size': maxsz})
    bdevs = []
    for fls, al, alo, size, pname, flags in entries('block_devices', '<QIIQ36sI'):
        bdevs.append({'first_logical_sector': fls, 'alignment': al, 'alignment_offset': alo,
                      'size': size, 'partition_name': pname.split(b'\x00')[0].decode(), 'flags': flags})
    for p in parts:
        p['size'] = sum(exts[p['first_extent_index'] + j]['num_sectors'] for j in range(p['num_extents'])) * SECTOR
        p['extents'] = [exts[p['first_extent_index'] + j] for j in range(p['num_extents'])]
    return {'geometry': {'metadata_max_size': meta_max, 'metadata_slot_count': slot_count,
                         'logical_block_size': lbs},
            'header': {'major': major, 'minor': minor, 'header_size': header_size, 'tables_size': tables_size},
            'partitions': parts, 'groups': groups, 'block_devices': bdevs}

def extract(f, super_off, part, out_path):
    with open(out_path, 'wb') as out:
        for e in part['extents']:
            assert e['target_type'] == 0, f"non-LINEAR extent in {part['name']}"
            f.seek(super_off + e['target_data'] * SECTOR)
            left = e['num_sectors'] * SECTOR
            while left:
                chunk = f.read(min(left, 8 * 1024 * 1024))
                assert chunk, 'EOF during extract'
                out.write(chunk); left -= len(chunk)

if __name__ == '__main__':
    img, mode = sys.argv[1], sys.argv[2]
    with open(img, 'rb') as f:
        gpt = parse_gpt(f)
        print('GPT:', json.dumps(gpt), file=sys.stderr)
        sup = next(p for p in gpt if p['name'] == 'super')
        lp = parse_lp(f, sup['offset'])
        if mode == 'dump':
            print(json.dumps({'gpt_super': sup, 'lp': lp}, indent=1))
        elif mode == 'extract':
            name, outp = sys.argv[3], sys.argv[4]
            part = next(p for p in lp['partitions'] if p['name'] == name)
            extract(f, sup['offset'], part, outp)
            print(f"extracted {name}: {part['size']} bytes -> {outp}", file=sys.stderr)
