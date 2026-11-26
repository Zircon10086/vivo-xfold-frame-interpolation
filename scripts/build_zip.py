#!/usr/bin/env python3
"""打包 module/ 为 KernelSU 可刷入的 zip。"""
import os
import sys
import time
import zipfile


def build(root: str, out: str) -> int:
    entries = []
    for dp, dn, fn in os.walk(root):
        for f in fn:
            if f == ".DS_Store":
                continue
            p = os.path.join(dp, f)
            entries.append((p, os.path.relpath(p, root).replace("\\", "/")))
    entries.sort(key=lambda x: x[1])
    os.makedirs(os.path.dirname(out), exist_ok=True)
    if os.path.exists(out):
        os.remove(out)
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for p, rel in entries:
            st = os.stat(p)
            zi = zipfile.ZipInfo(rel, time.localtime(st.st_mtime)[:6])
            zi.external_attr = (0o755 if p.endswith(".sh") else 0o644) << 16
            zi.compress_type = zipfile.ZIP_DEFLATED
            with open(p, "rb") as fh:
                z.writestr(zi, fh.read())
    return len(entries)


if __name__ == "__main__":
    root, out = sys.argv[1], sys.argv[2]
    n = build(root, out)
    print(f"{out}  ({n} files)")
