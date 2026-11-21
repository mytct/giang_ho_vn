#!/usr/bin/env python3
"""Xóa nền caro + bóng sàn trong sprite sheet raw 4x4.

Dùng: python3 tools/kill_shadow.py sheet.png [sheet2.png ...]

Mỗi ô của lưới 4x4:
1. flood-fill từ mọi pixel mép ô đi qua vùng "xám" (sat<25, 100<val<232)
   -> nền caro, bóng nối với nền, mảng caro hở đều bị xoá;
2. bóng enclosed (không nối nền): cụm xám tối (sat<22, 110<val<172) dẹt
   (rộng > 1.8x cao, cao < 14% ô).

Lưỡi dao/swoosh (val>=232), súng/đồ tối (val<=100) và màu nhân vật bão hoà
không nằm trong mặt nạ xám nên giữ nguyên.
"""

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

GRID = 4


def process_cell(cell: np.ndarray) -> tuple[int, int]:
    rgb = cell[:, :, :3].astype(int)
    a = cell[:, :, 3]
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    val = rgb.max(axis=2)
    hh, ww = a.shape
    gray = (a > 0) & (sat < 25) & (val > 100) & (val < 232)

    # 1) flood tu mép ô
    flooded = np.zeros(gray.shape, bool)
    q = deque()
    for x in range(ww):
        for y in (0, hh - 1):
            if gray[y, x] and not flooded[y, x]:
                flooded[y, x] = True
                q.append((y, x))
    for y in range(hh):
        for x in (0, ww - 1):
            if gray[y, x] and not flooded[y, x]:
                flooded[y, x] = True
                q.append((y, x))
    while q:
        cy, cx = q.popleft()
        for ny, nx in ((cy-1, cx), (cy+1, cx), (cy, cx-1), (cy, cx+1)):
            if 0 <= ny < hh and 0 <= nx < ww and gray[ny, nx] and not flooded[ny, nx]:
                flooded[ny, nx] = True
                q.append((ny, nx))
    n_flood = int(flooded.sum())
    cell[flooded, 3] = 0

    # 2) bóng enclosed dẹt
    a = cell[:, :, 3]
    m = (a > 0) & (sat < 22) & (val > 110) & (val < 172)
    seen = np.zeros(m.shape, bool)
    n_sh = 0
    for y in range(hh):
        for x in range(ww):
            if m[y, x] and not seen[y, x]:
                comp = []
                q = deque([(y, x)])
                seen[y, x] = True
                while q:
                    cy, cx = q.popleft()
                    comp.append((cy, cx))
                    for ny, nx in ((cy-1, cx), (cy+1, cx), (cy, cx-1), (cy, cx+1)):
                        if 0 <= ny < hh and 0 <= nx < ww and m[ny, nx] and not seen[ny, nx]:
                            seen[ny, nx] = True
                            q.append((ny, nx))
                if len(comp) < 1000:
                    continue
                ys = [p[0] for p in comp]
                xs = [p[1] for p in comp]
                bw = max(xs) - min(xs) + 1
                bh = max(ys) - min(ys) + 1
                if bw > 1.8 * bh and bh < 0.14 * hh:
                    for cy, cx in comp:
                        cell[cy, cx, 3] = 0
                    n_sh += len(comp)
    return n_flood, n_sh


def main() -> None:
    for arg in sys.argv[1:]:
        p = Path(arg)
        arr = np.array(Image.open(p).convert("RGBA"))
        h, w = arr.shape[:2]
        ch, cw = h // GRID, w // GRID
        t_bg = t_sh = 0
        for r in range(GRID):
            for c in range(GRID):
                bg, sh = process_cell(arr[r * ch : (r + 1) * ch, c * cw : (c + 1) * cw])
                t_bg += bg
                t_sh += sh
        Image.fromarray(arr).save(p)
        print(f"{p.name}: nen+bong noi {t_bg}px, bong enclosed {t_sh}px")


if __name__ == "__main__":
    main()
