#!/usr/bin/env python3
"""TreeOS default-home variant builder + block-delta maker.

Builds variant system images from the Phase 2b final image by re-running the
2b write-back method (edited partitions placed at their exact LP extent
offsets; LP metadata and vbmeta untouched — the final image's vbmeta already
carries flags=3).

Variants:
  nexus   : system_ext with /priv-app/NexusLauncherRelease removed (route 2)
  overlay : product with /overlay/TreeOSSettingsProviderOverlay.apk added (route 3)
  both    : nexus + overlay

Delta: 1 MiB block diff between two same-size images -> compact bundle the
Razer can apply to its local copy of the base image; final sha256 gates it.
"""
import hashlib, json, os, shutil, struct, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import lpmeta

WORK = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'work')
BASE_FINAL = os.path.join(WORK, 'treeos-system-final.img')
PRODUCT_TREEOS = os.path.join(WORK, 'product-treeos.img')
SYSTEM_EXT_STOCK = os.path.join(WORK, 'system_ext-stock.img')
LABEL = os.path.join(WORK, 'label.bin')
BLOCK = 1024 * 1024


def sha256(path):
    h = hashlib.sha256()
    with open(path, 'rb') as f:
        for chunk in iter(lambda: f.read(8 * 1024 * 1024), b''):
            h.update(chunk)
    return h.hexdigest()


def debugfs_cmds(img, cmds, label):
    script = os.path.join(WORK, f'defhome-{label}.cmds')
    with open(script, 'w') as f:
        f.write('\n'.join(cmds) + '\n')
    r = subprocess.run(['debugfs', '-w', '-f', script, img],
                       capture_output=True, text=True)
    print(r.stdout[-2000:])
    if r.returncode != 0:
        print(r.stderr[-2000:])
        raise SystemExit(f'debugfs failed for {label}')
    r2 = subprocess.run(['e2fsck', '-fn', img], capture_output=True, text=True)
    tail = (r2.stdout + r2.stderr).strip().splitlines()[-3:]
    print(f'e2fsck {label}:', ' | '.join(tail))


def build_product_with_overlay(overlay_apk):
    out = os.path.join(WORK, 'product-defhome.img')
    shutil.copyfile(PRODUCT_TREEOS, out)
    cmds = [
        f'write {overlay_apk} /overlay/TreeOSSettingsProviderOverlay.apk',
        'set_inode_field /overlay/TreeOSSettingsProviderOverlay.apk mode 0100644',
        f'ea_set -f {LABEL} /overlay/TreeOSSettingsProviderOverlay.apk security.selinux',
    ]
    debugfs_cmds(out, cmds, 'product-overlay')
    # read back + hash compare
    back = os.path.join(WORK, 'overlay-readback.apk')
    subprocess.run(['debugfs', '-R', f'dump -p /overlay/TreeOSSettingsProviderOverlay.apk {back}', out],
                   capture_output=True)
    assert sha256(back) == sha256(overlay_apk), 'overlay read-back hash mismatch'
    print('product overlay read-back hash OK:', sha256(out))
    return out


def build_system_ext_without_nexus():
    out = os.path.join(WORK, 'system_ext-defhome.img')
    shutil.copyfile(SYSTEM_EXT_STOCK, out)
    cmds = [
        'rm /priv-app/NexusLauncherRelease/NexusLauncherRelease.apk',
        'rm /priv-app/NexusLauncherRelease/oat/x86_64/NexusLauncherRelease.odex',
        'rm /priv-app/NexusLauncherRelease/oat/x86_64/NexusLauncherRelease.vdex',
        'rmdir /priv-app/NexusLauncherRelease/oat/x86_64',
        'rmdir /priv-app/NexusLauncherRelease/oat',
        'rmdir /priv-app/NexusLauncherRelease',
    ]
    debugfs_cmds(out, cmds, 'system_ext-nonus')
    r = subprocess.run(['debugfs', '-R', 'ls -l /priv-app', out], capture_output=True, text=True)
    assert 'NexusLauncher' not in r.stdout, 'NexusLauncher still present after removal'
    print('system_ext NexusLauncher removed OK:', sha256(out))
    return out


def assemble(variant, product_img=None, system_ext_img=None):
    out = os.path.join(WORK, f'treeos-system-{variant}.img')
    shutil.copyfile(BASE_FINAL, out)
    with open(BASE_FINAL, 'rb') as f:
        gpt = lpmeta.parse_gpt(f)
        sup = next(p for p in gpt if p['name'] == 'super')
        lp = lpmeta.parse_lp(f, sup['offset'])
    offs = {}
    for p in lp['partitions']:
        e = p['extents'][0]
        offs[p['name']] = sup['offset'] + e['target_data'] * 512
    with open(out, 'r+b') as f:
        for name, img in (('product', product_img), ('system_ext', system_ext_img)):
            if img is None:
                continue
            with open(img, 'rb') as pf:
                data = pf.read()
            f.seek(offs[name])
            f.write(data)
            print(f'wrote {name} ({len(data)} B) at {offs[name]}')
    # vbmeta magic sanity (flags already 3 from 2b; untouched here)
    with open(out, 'rb') as f:
        f.seek(1048576)
        assert f.read(4) == b'AVB0', 'vbmeta magic lost'
    print(f'variant {variant}: sha256 {sha256(out)}')
    return out


def make_delta(base, variant, delta_path):
    assert os.path.getsize(base) == os.path.getsize(variant)
    size = os.path.getsize(base)
    entries = []
    with open(base, 'rb') as fb, open(variant, 'rb') as fv, open(delta_path, 'wb') as out:
        # .bin is exactly the changed blocks' bytes, concatenated in idx order;
        # all metadata lives in the .idx JSON sidecar.
        idx = 0
        while True:
            b = fb.read(BLOCK)
            v = fv.read(BLOCK)
            if not b:
                break
            if b != v:
                entries.append(idx)
                out.write(v)
            idx += 1
    with open(delta_path + '.idx', 'w') as f:
        json.dump({'block_size': BLOCK, 'file_size': size,
                   'blocks': entries, 'variant_sha256': sha256(variant)}, f)
    print(f'delta: {len(entries)} blocks changed -> {delta_path} '
          f'({os.path.getsize(delta_path)} B), idx {delta_path}.idx')
    return entries


if __name__ == '__main__':
    cmd = sys.argv[1]
    if cmd == 'delta':
        variant = sys.argv[2]
        out = os.path.join(WORK, f'treeos-system-{variant}.img')
        make_delta(BASE_FINAL, out, os.path.join(WORK, f'delta-{variant}.bin'))
    elif cmd == 'build':
        variant = sys.argv[2]  # nexus | overlay | both
        overlay_apk = sys.argv[3] if len(sys.argv) > 3 else None
        prod = sext = None
        if variant in ('overlay', 'both'):
            assert overlay_apk, 'overlay apk path required'
            prod = build_product_with_overlay(overlay_apk)
        if variant in ('nexus', 'both'):
            sext = build_system_ext_without_nexus()
        out = assemble(variant, prod, sext)
        make_delta(BASE_FINAL, out, os.path.join(WORK, f'delta-{variant}.bin'))
    else:
        raise SystemExit(f'unknown cmd {cmd}')
