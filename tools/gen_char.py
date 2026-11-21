#!/usr/bin/env python3
"""Generate character portraits via Gemini Image API.

Usage:
    GEMINI_API_KEY=... python3 tools/gen_char.py out.png "prompt"

Post-processing: flood-remove the flat background from the corners,
resize to 192x192 nearest-neighbor, save as RGBA PNG.
"""

import io
import sys
import os
import collections

from google import genai
from google.genai import types
from PIL import Image

MODEL = "gemini-2.5-flash-image"
SIZE = (192, 192)
STYLE = (
    "Detailed pixel art portrait, head and shoulders bust, retro 16-bit game style, "
    "limited palette with clean pixel shading, transparent background, "
    "no text, no border, no frame. Vietnamese street gangster theme. "
)


def remove_bg(im: Image.Image, tol: int = 40) -> Image.Image:
    """Flood-fill transparent from the border so only the backdrop clears."""
    im = im.convert("RGBA")
    w, h = im.size
    px = im.load()

    def near(c1, c2):
        return all(abs(a - b) <= tol for a, b in zip(c1[:3], c2[:3]))

    bg = px[0, 0]
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
        if c[3] == 0:
            pass
        elif not near(c, bg):
            continue
        px[x, y] = (0, 0, 0, 0)
        q.extend(((x + 1, y), (x - 1, y), (x, y + 1), (x, y - 1)))
    return im


def generate(out_path: str, prompt: str) -> None:
    key = os.environ.get("GEMINI_API_KEY")
    if not key:
        sys.exit("GEMINI_API_KEY not set")
    client = genai.Client(api_key=key)
    resp = client.models.generate_content(
        model=MODEL,
        contents=STYLE + prompt,
        config=types.GenerateContentConfig(response_modalities=["IMAGE"]),
    )
    raw = None
    for part in resp.candidates[0].content.parts:
        if part.inline_data and part.inline_data.data:
            raw = part.inline_data.data
            break
    if raw is None:
        sys.exit(f"no image returned: {resp.text if resp.text else resp}")
    im = Image.open(io.BytesIO(raw))
    im = remove_bg(im)
    im = im.resize(SIZE, Image.NEAREST)
    im.save(out_path)
    print(f"saved {out_path} {im.size} {im.mode}")


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    generate(sys.argv[1], sys.argv[2])
