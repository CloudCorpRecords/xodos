#!/usr/bin/env python3
"""Minimal Android binary XML (AXML) dumper: elements + attributes as text."""
import struct, sys
sys.path.insert(0, '/home/hatch/workspace/tree-os/image-surgery')
from arsc import read_string_pool, value_str

def dump(buf):
    typ, hsize, size = struct.unpack_from('<HHI', buf, 0)
    off = hsize
    pool, off = read_string_pool(buf, off)
    # resource map may follow; skip until start-namespace/element chunks
    depth = 0
    while off < size:
        ctyp, chsize, csize = struct.unpack_from('<HHI', buf, off)
        if ctyp == 0x0102:  # START_ELEMENT
            ns, name = struct.unpack_from('<II', buf, off + 16)
            attr_start, attr_size, attr_count = struct.unpack_from('<HHH', buf, off + 24)
            el = pool[name] if name < len(pool) else f'?{name}'
            attrs = []
            ap = off + 16 + attr_start
            for i in range(attr_count):
                ans, aname, araw = struct.unpack_from('<III', buf, ap + i * 20)
                vsz, _r0, vtyp, vdata = struct.unpack_from('<HBBI', buf, ap + i * 20 + 12)
                aval = pool[araw] if araw != 0xFFFFFFFF and araw < len(pool) else value_str(vtyp, vdata, pool)
                attrs.append(f'{pool[aname]}={aval}')
            print('  ' * depth + f'<{el} ' + ' '.join(attrs) + '>')
            depth += 1
        elif ctyp == 0x0103:  # END_ELEMENT
            depth -= 1
            ns, name = struct.unpack_from('<II', buf, off + 16)
            el = pool[name] if name < len(pool) else f'?{name}'
            print('  ' * depth + f'</{el}>')
        elif ctyp == 0x0104:  # TEXT
            idx = struct.unpack_from('<I', buf, off + 16)[0]
            print('  ' * depth + f'TEXT {pool[idx]!r}')
        if csize == 0:
            break
        off += csize

if __name__ == '__main__':
    dump(open(sys.argv[1], 'rb').read())
