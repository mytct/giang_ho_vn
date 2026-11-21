#!/usr/bin/env python3
"""Post-process a downloaded character image into a game portrait asset.

Usage: python3 tools/char_post.py <src.png> <dst.png>

Flood-removes the flat background from the border, crops a centered square
around the character, resizes to 192x192 nearest-neighbor, saves RGBA PNG.
"""

import collections
import sys

from PIL import Image


def main() -> None:
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    src, dst = sys.argv[1], sys.argv[2]
    im = Image.open(src).convert("RGBA")
    w, h = im.size
    px = im.load()

    def near(c, bg, tol):
        return all(abs(a - b) <= tol for a, b in zip(c[:3], bg))

    bg = px[2, 2]
    tol = 10
    seen = set()
    q = collections.deque()
    for x in range(w):
        q.append((x, 0))
        q.append((x, h - 1))
    for y in range(h):
        q.append((0, y))
        q.append((w - 1, y))
    while q:
        x, y = q.popleft()
        if not (0 <= x < w and 0 <= y < h) or (x, y) in seen:
            continue
        seen.add((x, y))
        c = px[x, y]
        if c[3] != 0 and near(c, bg, tol):
            px[x, y] = (0, 0, 0, 0)
            q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))

    l, t, r, b = im.getbbox()
    side = max(r - l, b - t)
    cx, cy = (l + r) // 2, (t + b) // 2
    l2 = max(0, cx - side // 2)
    t2 = max(0, cy - side // 2)
    im2 = im.crop((l2, t2, min(w, l2 + side), min(h, t2 + side)))
    im2 = im2.resize((192, 192), Image.NEAREST)
    im2.save(dst)
    print(f"saved {dst} {im2.size} {im2.mode}")


if __name__ == "__main__":
    main()
