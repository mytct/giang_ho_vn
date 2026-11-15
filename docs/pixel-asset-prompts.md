# Prompt ASSET pixel — Giang Hồ Bụi Đời

Dùng cho Gemini/Nano Banana để gen **asset rời**, không phải mockup full-screen.
Mọi prompt đều nền trong suốt, không chữ, đúng grid. Chữ/số để Flutter render.

---

## BASE ASSET BLOCK (dán trước mọi prompt)

```
Pixel art game asset, 16-bit SNES style, crisp pixel grid 32px, no anti-aliasing,
flat colors, 1px black outline, 2px top-left bevel highlight, 2px bottom-right shade.
Palette: #0A0B10 #161922 #1C2029 #262B36 #FF2E63 #00E5D0 #FFC93C #EDEFF5 #8A90A0 #3EE08F #FF5A5A.
PNG with alpha channel, transparent background, no checkerboard, no drop shadow.
No text, no letters, no numbers, no logo, no watermark.
```

---

## 1. UI KIT SHEET

```
[BASE ASSET BLOCK]
Pixel UI kit sprite sheet, everything aligned to a 32px grid with equal spacing.
Row 1: four 9-slice panels, 48x48 each — dark panel #161922, cyan-border panel,
gold-border panel, red-border panel. Each panel has a uniform 8px border and a
completely flat empty center with no pattern or ornament.
Row 2: three buttons 64x28 — normal, pressed, disabled.
Row 3: one chip 48x24, one HP bar frame 96x16, one HP fill strip 96x12,
one item card frame 64x64 with empty center.
No text, transparent background.
```

## 2. PANEL 9-SLICE (gen riêng từng màu để sạch)

```
[BASE ASSET BLOCK]
One pixel-art 9-slice panel, front view, 48x48, uniform 8px border on all four sides,
flat solid #161922 interior with no pattern, intact corner pixels,
#262B36 border, black outer outline, 1px light bevel top-left, 1px shade bottom-right.
Centered, transparent outside the panel. No text, no icons.
```
Đổi `#262B36` thành `#00E5D0` (cyan), `#FFC93C` (gold), `#FF5A5A` (red) cho bản khác.

## 3. BUTTON 3 TRẠNG THÁI

```
[BASE ASSET BLOCK]
Pixel button sprite sheet: three states side by side, 64x28 each.
normal: flat #FF2E63 fill, light bevel top-left, dark bevel bottom-right, black outline.
pressed: darker fill, inverted bevel, shifted 2px down.
disabled: desaturated gray with low contrast.
Transparent background, no text.
```

## 4. ICON SET 32×32

```
[BASE ASSET BLOCK]
Pixel icon set, 12 icons on a 4x3 grid, each 32x32 with equal 8px gaps,
consistent 2px stroke weight, flat colors, 1px black outline.
Icons: gold coin, cyan star (uy tín), pink fist (lực), cyan head (đàn em),
cyan group of three heads (lính đông), territory flag, shield, fire, skull,
padlock, plus, heart.
No text, transparent background.
```

## 5. NAV ICON SET

```
[BASE ASSET BLOCK]
Five mobile bottom-nav pixel icons in a row, 32x32 each, transparent:
storefront, map, squad of soldiers, market fire, trophy.
Same stroke weight, same palette, no text, no labels.
```

## 6. CHARACTER SPRITE SHEET

```
[BASE ASSET BLOCK]
Pixel art sprite sheet, side-view beat-em-up gangster, 32x48 per frame,
4 columns: idle, walk, attack with cleaver, hurt. One facing direction.
Flat shading with 1px black outline, no shadow, transparent background, no text.
Palette: cyan shirt for the player gang, pink shirt for the enemy gang.
```

## 7. BOSS PORTRAIT

```
[BASE ASSET BLOCK]
Pixel art portrait, 96x96, bust shot of a humorous Vietnamese mafia boss,
gold chain, cigarette, scar, confident grin, stylized cartoon, not realistic,
transparent background, no text.
```

## 8. BACKGROUND HẺM (không UI, không chữ)

```
[BASE ASSET BLOCK]
Pixel art background, portrait 390x844, Saigon back alley at night:
corrugated metal walls, plastic stools, motorbike, karaoke neon signs (no readable text),
hanging wires, puddles reflecting neon. Dark palette with pink and cyan neon accents.
Layered for parallax: far buildings, mid alley, near props.
No UI, no text, no characters.
```

## 9. BACKGROUND QUÁN / KARAOKE

```
[BASE ASSET BLOCK]
Pixel art background, portrait 390x844, Vietnamese karaoke bar interior at night:
neon lights, small stage, plastic chairs, beer crates, smoke, warm pink and cyan glow.
Flat pixel shading, no anti-aliasing. No UI, no text, no characters.
```

---

## NEGATIVE (asset)

```
3d, photorealistic, smooth gradient, blur, anti-aliasing, checkerboard background,
white background, text, letters, numbers, logo, watermark, real firearm, gore,
drop shadow, rounded corners, ornate panel center, inconsistent border width,
perspective, isometric, too many colors
```

---

## BẢNG MAP: PROMPT NÀO RA FILE NÀO

| Prompt | Ảnh trả về | Lưu thành |
|---|---|---|
| 1. UI KIT SHEET | 1 sheet nhiều món | cắt theo hàng: panel_dark/cyan/gold/red → btn_normal/pressed/disabled → chip_dark → bar_frame → card_frame |
| 2. PANEL (màu dark) | 1 panel | `panel_dark.png` |
| 2b. PANEL (đổi viền cyan) | 1 panel | `panel_cyan.png` |
| 2c. PANEL (đổi viền gold) | 1 panel | `panel_gold.png` |
| 2d. PANEL (đổi viền red) | 1 panel | `panel_red.png` |
| 2e. PANEL (đổi viền pink) | 1 panel | `panel_pink.png` |
| 3. BUTTON SHEET | 1 sheet 3 nút trái→phải | `btn_normal.png` → `btn_pressed.png` → `btn_disabled.png` |
| 4. ICON SET 4×3 | 1 sheet 12 icon | đọc theo đúng thứ tự prompt: hàng 1 coin, uy, power, crew; hàng 2 minion, flag, shield, fire; hàng 3 skull, lock, plus, heart |
| 5. NAV ICON | 1 hàng 5 icon trái→phải | nav_home → nav_map → nav_crew → nav_shop → nav_gang |
| 6. SPRITE (áo cyan) | 1 sheet 4 frame | `gangster_player_sheet.png` |
| 6b. SPRITE (áo pink) | 1 sheet 4 frame | `gangster_enemy_sheet.png` |
| 7. BOSS | 1 chân dung | `boss_chuong1.png` (gen lại cho chương 2–6) |
| 8. BG HẺM | 1 ảnh nền | `bg_alley.png` |
| 9. BG KARAOKE | 1 ảnh nền | `bg_karaoke.png` |

Muốn `bg_market / bg_bridge / bg_shop / bg_brawl`: giữ prompt 8, đổi phần setting
(chợ đêm / bến xe-cầu / chợ đen / sân chém) và lưu đúng tên.

**Nếu sheet không đúng thứ tự:** đừng đoán. Bỏ ảnh vào repo rồi báo tôi — tôi đọc ảnh,
nhìn từng ô và đặt tên/cắt đúng. Hoặc gen lại từng asset riêng cho chắc.

---

## SPEC XUẤT FILE & ĐẶT TÊN

Quy ước: snake_case, không dấu, chữ thường, chỉ 1x (không @2x), luôn `.png` alpha.
AI không tự đặt tên — ông lưu đúng tên dưới đây thì tôi nối code không phải sửa.

### client/assets/ui/
| Tên file | Kích thước | 9-slice margin | Dùng cho |
|---|---|---|---|
| panel_dark.png | 48×48 | 8px | panel thường |
| panel_cyan.png | 48×48 | 8px | panel nhấn cyan |
| panel_gold.png | 48×48 | 8px | panel quỹ/thưởng |
| panel_red.png | 48×48 | 8px | panel chiến/cảnh báo |
| panel_pink.png | 48×48 | 8px | panel băng của mình |
| btn_normal.png | 64×28 | 6px | nút thường |
| btn_pressed.png | 64×28 | 6px | nút đang bấm |
| btn_disabled.png | 64×28 | 6px | nút khoá |
| chip_dark.png | 48×24 | 6px | chip thường |
| chip_cyan.png | 48×24 | 6px | chip uy/lực |
| chip_gold.png | 48×24 | 6px | chip tiền |
| bar_frame.png | 96×16 | 4px | khung thanh máu/EXP |
| bar_fill_hp.png | 96×12 | — | ruột máu (scale ngang) |
| bar_fill_xp.png | 96×12 | — | ruột EXP (scale ngang) |
| card_frame.png | 64×64 | 8px | khung card đồ |
| dialog_frame.png | 96×96 | 12px | khung hội thoại |

### client/assets/icons/ (32×32)
`icon_coin.png` (tiền) · `icon_uy.png` (uy tín) · `icon_power.png` (lực) ·
`icon_crew.png` (đàn em) · `icon_minion.png` (lính đông) · `icon_flag.png` (địa bàn) ·
`icon_shield.png` (khiên) · `icon_fire.png` (độ nóng) · `icon_skull.png` (boss) ·
`icon_lock.png` (khoá) · `icon_plus.png` (mộ quân) · `icon_heart.png` (máu)

### client/assets/nav/ (32×32)
`nav_home.png` · `nav_map.png` · `nav_crew.png` · `nav_shop.png` · `nav_gang.png`

### client/assets/sprites/
| Tên file | Kích thước | Ghi chú |
|---|---|---|
| gangster_player_sheet.png | 128×48 | 4 frame 32×48: idle/walk/attack/hurt |
| gangster_enemy_sheet.png | 128×48 | cùng layout, áo hồng |
| boss_chuong1.png | 96×96 | chân dung trùm chương 1 |
| boss_chuong2.png ... boss_chuong6.png | 96×96 | mỗi chương 1 ảnh |

### client/assets/scene/ (390×844 @1x, hoặc 1170×2532 @3x)
`bg_alley.png` (hẻm home) · `bg_karaoke.png` · `bg_market.png` (chợ) ·
`bg_bridge.png` (bến xe/cầu) · `bg_shop.png` (chợ đen) · `bg_brawl.png` (sân chém)

Lưu ý: nếu ông xuất @3x thì thêm hậu tố `@3x` (vd `bg_alley@3x.png`); icon/panel giữ 1x.


## Kiểm tra sau khi gen

- Panel: zoom 800% xem 4 góc có đồng nhất không, ruột có sạch không.
- Icon: nền phải alpha thật (mở bằng editor, không có ô caro).
- Sprite: các frame phải cùng kích thước, cùng baseline chân.
- Nếu model trả nền trắng/caro: gen lại với "isolated on transparent, alpha channel, no backdrop".
