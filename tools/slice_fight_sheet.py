#!/usr/bin/env python3
"""Cắt sprite sheet 4x4 (PHASE 2D) thành 16 frame PNG cho trận đánh.

Dùng: python3 tools/slice_fight_sheet.py [docs/raw/sheet_fight_player.png ...]

Pipeline mỗi sheet:
1. nhận diện 2-4 màu xám chủ đạo (checkerboard giả) và xoá component lớn nhất
   của mask đó — giữ nguyên vùng trắng bên trong nhân vật (răng, mắt...);
2. cắt chữ label dưới đáy ô (cụm nội dung thấp tách bằng gap dọc);
3. despeckle: pixel màu checker lẻ loi giữa vùng trong suốt;
4. drop mảnh nhỏ (<2500px) — sót chữ/mẩu;
5. trim alpha, scale ĐỒNG NHẤT cả sheet (tham chiếu frame đứng idle1 = 192px),
   đặt đáy-giữa vào ô 256x256 để chân chạm cùng một đường đất;
6. gom 16 ô thành MỘT atlas 1024x1024 mỗi nhân vật (`atlas_p.png`, `atlas_m1.png`...).
"""
from __future__ import annotations

import sys
from collections import deque
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
RAW = ROOT / "docs" / "raw"
OUT = ROOT / "client" / "assets" / "fight"

SLOTS = [
    "run1", "run2", "run3", "run4",
    "idle1", "idle2", "atk1", "atk2",
    "hurt", "ko1", "ko2", "win",
    "gun1", "gun2", "aim", "fire",
]
GRID = 4
CELL = 256
TARGET_H = 192
MIN_BLOB = 2500


def _components(mask: np.ndarray) -> tuple[np.ndarray, dict[int, int]]:
    h, w = mask.shape
    lbl = np.zeros((h, w), np.int32)
    sizes: dict[int, int] = {}
    cur = 0
    for y in range(h):
        for x in range(w):
            if mask[y, x] and lbl[y, x] == 0:
                cur += 1
                stack = [(y, x)]
                lbl[y, x] = cur
                n = 0
                while stack:
                    cy, cx = stack.pop()
                    n += 1
                    if cy > 0 and mask[cy - 1, cx] and lbl[cy - 1, cx] == 0:
                        lbl[cy - 1, cx] = cur
                        stack.append((cy - 1, cx))
                    if cy < h - 1 and mask[cy + 1, cx] and lbl[cy + 1, cx] == 0:
                        lbl[cy + 1, cx] = cur
                        stack.append((cy + 1, cx))
                    if cx > 0 and mask[cy, cx - 1] and lbl[cy, cx - 1] == 0:
                        lbl[cy, cx - 1] = cur
                        stack.append((cy, cx - 1))
                    if cx < w - 1 and mask[cy, cx + 1] and lbl[cy, cx + 1] == 0:
                        lbl[cy, cx + 1] = cur
                        stack.append((cy, cx + 1))
                sizes[cur] = n
    return lbl, sizes


def remove_checker(img: Image.Image) -> Image.Image:
    arr = np.array(img)
    rgb = arr[:, :, :3].astype(int)
    sat = rgb.max(axis=2) - rgb.min(axis=2)
    cand = (sat < 14) & (rgb.min(axis=2) > 100)
    if int(cand.sum()) < 1000:
        return img
    q = rgb[cand] // 12
    keys, counts = np.unique(q, axis=0, return_counts=True)
    order = np.argsort(-counts)[:4]
    cols = [keys[i] * 12 + 6 for i in order]
    mask = np.zeros(arr.shape[:2], bool)
    for c in cols:
        mask |= np.abs(rgb - c).sum(axis=2) < 66

    lbl, sizes = _components(mask)
    if not sizes:
        return img
    big = max(sizes.values())
    kill = np.zeros_like(mask)
    for cid, n in sizes.items():
        if n >= 40000:  # component nền checker rất lớn
            kill |= lbl == cid
    arr[kill, 3] = 0
    print(f"  bỏ nền: {int(kill.sum())}px, {len(cols)} màu mẫu")

    # despeckle: pixel màu checker đứng lẻ loi giữa vùng trống (cửa sổ 5x5)
    a = arr[:, :, 3]
    match = np.zeros(a.shape, bool)
    for c in cols:
        match |= np.abs(rgb - c).sum(axis=2) < 66
    empty = (a == 0).astype(np.int32)
    ii = np.zeros((a.shape[0] + 1, a.shape[1] + 1), np.int32)
    ii[1:, 1:] = np.cumsum(np.cumsum(empty, 0), 1)
    h, w = a.shape
    ys0 = np.clip(np.arange(h) - 2, 0, h)
    ys1 = np.clip(np.arange(h) + 3, 0, h)
    xs0 = np.clip(np.arange(w) - 2, 0, w)
    xs1 = np.clip(np.arange(w) + 3, 0, w)
    box = (
        ii[np.ix_(ys1, xs1)]
        - ii[np.ix_(ys0, xs1)]
        - ii[np.ix_(ys1, xs0)]
        + ii[np.ix_(ys0, xs0)]
    )
    kill2 = match & (a > 0) & (box > 12)
    arr[kill2, 3] = 0
    return Image.fromarray(arr)


def drop_lines(img: Image.Image) -> Image.Image:
    """Drop blob dạng đường kẻ mảnh dài (viền ô vẽ trong cell)."""
    arr = np.array(img)
    solid = arr[:, :, 3] > 0
    lbl, sizes = _components(solid)
    for cid in sizes:
        ys, xs = np.nonzero(lbl == cid)
        bw = int(xs.max() - xs.min() + 1)
        bh = int(ys.max() - ys.min() + 1)
        if (bw <= 4 and bh >= 40) or (bh <= 4 and bw >= 40):
            arr[lbl == cid, 3] = 0
    return Image.fromarray(arr)


def cut_label(cell: Image.Image) -> Image.Image:
    """Cụm nội dung thấp nhất (dưới gap dọc ≥6px) cao ≤48px = chữ → xoá."""
    arr = np.array(cell)
    rows = (arr[:, :, 3] > 0).sum(axis=1)
    nz = np.nonzero(rows)[0]
    if len(nz) == 0:
        return cell
    bottom = int(nz[-1])
    y = bottom
    while y >= 0 and rows[y] > 0:
        y -= 1
    top = y + 1
    h = len(rows)
    if bottom - top + 1 <= 48 and top > h * 0.55:
        arr[top:, :, 3] = 0
    return Image.fromarray(arr)


def drop_small_blobs(img: Image.Image, min_area: int) -> Image.Image:
    arr = np.array(img)
    solid = arr[:, :, 3] > 0
    lbl, sizes = _components(solid)
    if not sizes:
        return img
    biggest = max(sizes.values())
    threshold = max(min_area, int(biggest * 0.10))
    for cid, n in sizes.items():
        if n < threshold:
            arr[lbl == cid, 3] = 0
    return Image.fromarray(arr)


def bbox_of(img: Image.Image):
    return img.split()[3].getbbox()


def slice_sheet(path: Path, prefix: str) -> None:
    img = Image.open(path).convert("RGBA")
    if img.size != (1024, 1024):
        print(f"! {path.name}: kích thước {img.size}, tự scale về 1024x1024")
        img = img.resize((1024, 1024), Image.LANCZOS)
    img = remove_checker(img)

    cells: list[Image.Image | None] = []
    for idx in range(len(SLOTS)):
        r, c = divmod(idx, GRID)
        # lệch vào 4px để né đường viền ô giữa các cell
        cell = img.crop(
            (c * CELL + 4, r * CELL + 4, (c + 1) * CELL - 4, (r + 1) * CELL - 4)
        )
        cell = drop_lines(cell)
        cell = cut_label(cell)
        cell = drop_small_blobs(cell, MIN_BLOB)
        bb = bbox_of(cell)
        cells.append(cell.crop(bb) if bb else None)

    ref = cells[4] or cells[5] or cells[11] or next(x for x in cells if x)
    scale = TARGET_H / ref.height
    print(f"  scale cả sheet: x{scale:.3f} (chiều cao đứng {ref.height}px)")

    OUT.mkdir(parents=True, exist_ok=True)
    atlas = Image.new("RGBA", (CELL * GRID, CELL * GRID), (0, 0, 0, 0))
    for idx, (slot, body) in enumerate(zip(SLOTS, cells)):
        if body is None:
            print(f"!! ô trống — {prefix}:{slot}")
            continue
        new_w = max(1, min(CELL, round(body.width * scale)))
        new_h = max(1, min(CELL, round(body.height * scale)))
        body = body.resize((new_w, new_h), Image.LANCZOS)
        r, c = divmod(idx, GRID)
        atlas.paste(
            body,
            (c * CELL + (CELL - new_w) // 2, r * CELL + CELL - new_h),
            body,
        )
    dest = OUT / f"atlas_{prefix}.png"
    atlas.save(dest)
    print(f"ok {dest.name} (4x4, 1024x1024)")


def main() -> None:
    args = sys.argv[1:]
    jobs = [
        (RAW / "sheet_fight_player.png", "p"),
        (RAW / "sheet_fight_enemy.png", "e"),
    ]
    if args:
        jobs = [(Path(a), Path(a).stem.split("_")[-1]) for a in args]
    for path, prefix in jobs:
        if not path.exists():
            print(f"bỏ qua (chưa có): {path}")
            continue
        print(f"== {path.name}")
        slice_sheet(path, prefix)


if __name__ == "__main__":
    main()
