# Bộ prompt pixel-art UI — Giang Hồ Bụi Đời

Cách dùng với Gemini (Nano Banana):
1. Dán **STYLE BLOCK** trước, rồi dán 1 prompt màn hình.
2. Mỗi lần chỉ gen **1 màn**, tỉ lệ dọc 9:19.5.
3. Ra ảnh ưng ý → upload lại làm reference và nói: "Keep this exact style and palette, now show the map screen."
4. Chữ tiếng Việt hay bị sai dấu — thêm: "Vietnamese text must use correct diacritics, do not invent letters."

---

## STYLE BLOCK (dán trước mọi prompt)

```
16-bit pixel art mobile game UI mockup, portrait 9:19.5, crisp pixel grid,
no anti-aliasing, no blur, flat colors with 1px black outline and 2px top bevel highlight.
Limited palette: background #0A0B10, panel #161922, panel2 #1C2029, line #262B36,
neon pink #FF2E63, cyan #00E5D0, gold #FFC93C, off-white #EDEFF5, muted #8A90A0,
green #3EE08F, red #FF5A5A.
Theme: Vietnamese street mafia in a Saigon back alley — karaoke bar, massage parlor,
motorbike parking, beer pub, plastic stools, corrugated metal, neon Vietnamese signage.
Stylized cartoon weapons only, no real brands, no gore.
UI style: chunky beveled panels, pixel icons, pixel font, big glowing primary button,
clean hierarchy, all UI text in Vietnamese with correct diacritics.
```

---

## 1. Home / idle

```
[STYLE BLOCK]
Screen: idle economy home screen.
Top bar: player name "ĐẠI CA A", rank "Đại ca", money "125.0K đ", cyan "uy" chip, pink "lực" chip.
Section title "BĂNG CỦA MÀY".
List of 4 business cards with pixel icons and income:
- "Karaoke Phượng Hoàng" — 3.2K/giây — button "NÂNG 1.2K"
- "Matxa Bình Dân" — 2.1K/giây — button "NÂNG 900"
- "Bãi Giữ Xe" — 800/giây — button "NÂNG 300"
- "Quán Nhậu Cô Ba" — locked with padlock, "Cần đạt Đại ca"
Bottom nav: 5 pixel icons (Bang, Map, Quân, Chợ, Băng).
Small missions panel "NHIỆM VỤ" with a claim button.
```

## 2. Territory map

```
[STYLE BLOCK]
Screen: territory map, top-down pixel street map of a Saigon alley.
24 square territory tiles in a 6x4 grid, slightly organic street layout.
Tile colors: neutral gray = empty, red = NPC gang, cyan border = my gang, yellow = ally.
Each tile shows a tiny pixel landmark icon (karaoke, market, bridge, alley) and a small flag.
Header: "BẢN ĐỒ ĐỊA BÀN" with counter "2/6 ô".
Bottom sheet preview of selected tile: name "Hẻm 12", "thuế 20 · phòng thủ 55",
buttons "CHÉM" (red) and "NÂNG CẤP" (gold).
Legend chips: TRỐNG / BĂNG NPC / CỦA MÀY / ĐỒNG MINH.
```

## 3. Brawl / battle

```
[STYLE BLOCK]
Screen: side-view 2D pixel brawl, 3 gangsters on the left (mine) vs 3 on the right (enemy).
Chunky pixel characters with stylized weapons (cleaver, pipe, bat), no blood.
Top: two HP bars, names, VS badge.
Damage numbers pop up "-18", "CHÍ MẠNG -31" in gold.
Speed lines and dust pixels, slight screen shake feel.
Bottom: result panel "CHIẾM ĐƯỢC HẺM 12", loot "+2.4K đ", uy "+120",
wounded row "Lính bị thương 12 đứa", big teal button "XONG".
```

## 4. Army / minions

```
[STYLE BLOCK]
Screen: army management.
Top: squad stats "lực 146", "quân 4", "lính 120/500".
Section "ĐỘI HÌNH": 3 chunky chips Cân bằng / Tiên phong / Đánh lén.
Section "CHIA QUÂN GIỮ ĐẤT": rows with territory name and +/- steppers.
Section "LÍNH ĐÔNG": "112 khỏe · 8 bị thương · +146 lực",
two buttons "MỘ +10" (cyan) and "BĂNG BÓ" (green),
two item rows "Dao phay · đang có 60 · 150" and "Kiếm Nhật · đang có 15 · 400" with BUY buttons.
Small pixel soldiers marching in a row as decoration.
```

## 5. Gang / diplomacy

```
[STYLE BLOCK]
Screen: gang and diplomacy.
Header card: "BĂNG RẮN ĐỘC" tier badge T1, "Lv 2 · 2 đồng minh · 1 chiến · 12K quỹ",
button "QUỸ", warm banner "Chiến băng 20:00–22:00 · 4 điểm".
Gang list with tier chips T1/T2/T3 and relation tags: BĂNG MÀY / ĐỒNG MINH / ĐANG CHIẾN / NỘP CỐNG / THU CỐNG.
Diplomacy node graph: pixel nodes connected by cyan lines (ally), red lines (war),
gold arrows (tribute), legend and expiry labels.
Buttons: "KẾT MINH", "ĐÒI CỐNG", "TUYÊN CHIẾN".
```

## 6. UI kit / sprite sheet (để cắt asset)

```
[STYLE BLOCK]
Pixel art game UI kit sprite sheet on transparent background, no text, no mockup frame.
Include: 9-slice beveled panels (dark, cyan border, gold border, red border),
3 button states (normal, pressed, disabled), pixel icons (money coin, uy star, power fist,
crew head, minion group, territory flag, shield, fire, skull, lock, plus, heart),
HP bar frames, progress bar, currency chips, nav icons, item card frame, dialog box.
Everything aligned to a 32px grid, flat colors, 1px outlines, consistent palette.
```

---

## NEGATIVE PROMPT (dán kèm nếu tool hỗ trợ)

```
photorealistic, 3d render, smooth gradient, blurry, anti-aliased, glossy,
real brand logo, real firearm, blood, gore, watermark, gibberish text,
wrong Vietnamese diacritics, thin 1px fonts, perspective camera, isometric 3d,
too many colors, low contrast, cluttered layout
```

---

## Ghi chú triển khai Flutter

- Xin panel **9-slice** ở prompt UI kit, đừng bake text vào ảnh.
- Font pixel phải test dấu Việt: Pixelify Sans / VT323 thường thiếu vài dấu;
  fallback font thường cho câu dài, pixel font cho số + tiêu đề.
- Icon và panel nên là PNG nền trong suốt; scale bằng nearest-neighbor.
