#!/usr/bin/env python3
"""Minimal resources.arsc reader: dump package resources name -> typed value.
Handles string pools (utf8/utf16), type chunks, simple entries and bag entries.
Good enough to read config arrays/bools out of framework-res and RRO apks."""
import struct, sys, zipfile

RES_STRING_POOL_TYPE = 0x0001
RES_TABLE_PACKAGE_TYPE = 0x0200
RES_TABLE_TYPE_TYPE = 0x0201
RES_TABLE_TYPE_SPEC_TYPE = 0x0202
UTF8_FLAG = 0x100
NO_ENTRY = 0xFFFFFFFF

def read_string_pool(buf, off):
    typ, hsize, size = struct.unpack_from('<HHI', buf, off)
    assert typ == RES_STRING_POOL_TYPE, f'not a string pool at {off:#x}'
    count, style_count, flags, strings_start, styles_start = struct.unpack_from('<IIIII', buf, off + 8)
    is_utf8 = bool(flags & UTF8_FLAG)
    offsets = struct.unpack_from(f'<{count}I', buf, off + hsize)
    base = off + strings_start
    out = []
    for o in offsets:
        p = base + o
        if is_utf8:
            # utf16 len then utf8 len, each variable-length
            def u8len(p):
                if buf[p] & 0x80:
                    return ((buf[p] & 0x7F) << 8) | buf[p + 1], p + 2
                return buf[p], p + 1
            _, p = u8len(p)
            blen, p = u8len(p)
            out.append(buf[p:p + blen].decode('utf-8', 'replace'))
        else:
            ln = struct.unpack_from('<H', buf, p)[0]
            if ln & 0x8000:
                ln = ((ln & 0x7FFF) << 16) | struct.unpack_from('<H', buf, p + 2)[0]
                p += 4
            else:
                p += 2
            out.append(buf[p:p + ln * 2].decode('utf-16-le', 'replace'))
    return out, off + size

def value_str(vtype, vdata, pool):
    if vtype == 0x03:  # STRING
        return f'"{pool[vdata]}"' if 0 <= vdata < len(pool) else f'string@{vdata}'
    if vtype == 0x12:  # INT_BOOLEAN
        return 'true' if vdata else 'false'
    if vtype == 0x10:  # INT_DEC
        return str(struct.unpack('<i', struct.pack('<I', vdata))[0])
    if vtype == 0x01:  # REFERENCE
        return f'@0x{vdata:08x}'
    if vtype == 0x04:
        import struct as s
        return str(s.unpack('<f', s.pack('<I', vdata))[0])
    return f'type{vtype:#x}:{vdata:#x}'

TYPE_NAMES = {1:'attr',2:'id',3:'bool',4:'color',5:'dimen',6:'drawable',7:'fraction',
              8:'integer',9:'layout',10:'menu',11:'mipmap',12:'plurals',13:'string',
              14:'style',15:'xml',16:'array',17:'anim',18:'animator',19:'interpolator'}

def parse_arsc(buf):
    typ, hsize, size, pkg_count = struct.unpack_from('<HHII', buf, 0)
    assert typ == 0x0002, 'not arsc'
    off = hsize
    global_pool, off = read_string_pool(buf, off)
    results = []  # (pkgname, restype, name, value_str)
    end = size
    while off < end:
        ctyp, chsize, csize = struct.unpack_from('<HHI', buf, off)
        if ctyp == RES_TABLE_PACKAGE_TYPE:
            pkg_id = struct.unpack_from('<I', buf, off + 8)[0]
            name_raw = buf[off + 12:off + 12 + 256]
            pkg_name = name_raw.decode('utf-16-le', 'replace').split('\x00')[0]
            type_strings_off, key_strings_off = struct.unpack_from('<II', buf, off + 8 + 256 + 4)
            # layout: id(4) name(256) typeStrings(4) lastPublicType(4) keyStrings(4) lastPublicKey(4) typeIdOffset(4)
            type_strings_off = struct.unpack_from('<I', buf, off + 268)[0]
            key_strings_off = struct.unpack_from('<I', buf, off + 276)[0]
            type_pool, _ = read_string_pool(buf, off + type_strings_off)
            key_pool, _ = read_string_pool(buf, off + key_strings_off)
            sub = off + chsize
            pkg_end = off + csize
            while sub < pkg_end:
                styp, shsize, ssize = struct.unpack_from('<HHI', buf, sub)
                if styp == RES_TABLE_TYPE_TYPE:
                    type_id = buf[sub + 8]
                    type_flags = buf[sub + 9]
                    entry_count, entries_start = struct.unpack_from('<II', buf, sub + 12)
                    type_name = type_pool[type_id - 1] if 1 <= type_id <= len(type_pool) else TYPE_NAMES.get(type_id, str(type_id))
                    sparse = bool(type_flags & 0x01)
                    off16 = bool(type_flags & 0x02)
                    idxs = []
                    for i in range(entry_count):
                        if sparse and off16:
                            nidx, noff = struct.unpack_from('<HH', buf, sub + shsize + i * 4)
                            idxs.append((nidx, noff * 4))
                        elif sparse:
                            nidx, noff = struct.unpack_from('<II', buf, sub + shsize + i * 8)
                            idxs.append((nidx, noff * 4))
                        elif off16:
                            eoff0 = struct.unpack_from('<H', buf, sub + shsize + i * 2)[0]
                            idxs.append((i, eoff0 * 4))
                        else:
                            eoff0 = struct.unpack_from('<I', buf, sub + shsize + i * 4)[0]
                            idxs.append((i, eoff0))
                    for i, eoff in idxs:
                        if eoff == NO_ENTRY:
                            continue
                        ep = sub + entries_start + eoff
                        if ep + 8 > sub + ssize:
                            continue
                        esz, eflags, keyidx = struct.unpack_from('<HHI', buf, ep)
                        key = key_pool[keyidx] if keyidx < len(key_pool) else f'key{keyidx}'
                        if eflags & 0x0001:  # complex (bag)
                            if ep + esz > len(buf):
                                continue
                            # ResTable_map_entry: entry(esz total incl. parent ref + count); count at esz-4
                            cnt = struct.unpack_from('<I', buf, ep + esz - 4)[0]
                            if cnt > 4096:
                                continue
                            vals = []
                            mp = ep + esz
                            for j in range(cnt):
                                if mp + 12 > len(buf):
                                    break
                                _n, = struct.unpack_from('<I', buf, mp)
                                vsz, _r0, vtyp, vdata = struct.unpack_from('<HBBI', buf, mp + 4)
                                vals.append(value_str(vtyp, vdata, global_pool))
                                mp += 12
                            results.append((pkg_name, type_name, key, '[' + ', '.join(vals) + ']'))
                        else:
                            if ep + esz + 8 > len(buf):
                                continue
                            vsz, _r0, vtyp, vdata = struct.unpack_from('<HBBI', buf, ep + esz)
                            results.append((pkg_name, type_name, key, value_str(vtyp, vdata, global_pool)))
                sub += ssize if ssize else shsize
        off += csize if csize else chsize
    return results

if __name__ == '__main__':
    apk = sys.argv[1]
    pat = sys.argv[2].lower() if len(sys.argv) > 2 else ''
    z = zipfile.ZipFile(apk)
    buf = z.read('resources.arsc')
    for pkg, tname, key, val in parse_arsc(buf):
        line = f'{pkg} {tname}/{key} = {val}'
        if pat in line.lower():
            print(line)
