# Prompt gen asset rời — 1 prompt = 1 file

Bản này thay cho `pixel-asset-prompts.md` ở chỗ **không dùng sprite sheet** nữa:
mỗi prompt chỉ ra **đúng 1 món**, ông lưu đúng tên là tôi gắn vào UI, không phải cắt.

Quy tắc:
- Mỗi lần gen 1 prompt, 1 ảnh. Đừng xin "sheet" hay "set".
- Nếu tool cho chọn tỉ lệ: chọn gần nhất với ghi chú (dọc cho nền, vuông cho icon).
- Ảnh ra **to hơn spec là bình thường** — cứ để to, tôi downscale nearest-neighbor trong code.
- Icon / sprite / trùm: nền **trong suốt thật** (alpha). Nền cảnh: đục, không alpha.
- Không có chữ trong ảnh. Chữ Việt để Flutter render (model hay sai dấu).
- Nếu ảnh ra 2–3 món dính nhau → gen lại, thêm `exactly one object, nothing else in frame`.

Chỗ lưu: giữ đúng cây thư mục bên dưới. Lười thì quăng hết vào `docs/raw/`,
đặt tên gì cũng được, tôi đọc ảnh rồi đặt tên + resize hộ.

---

## STYLE BLOCK (dán trước mọi prompt asset)

```
16-bit SNES pixel art game asset, crisp 1:1 pixel grid, no anti-aliasing, no blur,
flat colors, 1px near-black outline, 2px top-left bevel highlight, 2px bottom-right shade.
Palette only: #0A0B10 #161922 #1C2029 #262B36 #FF2E63 #00E5D0 #FFC93C #EDEFF5 #8A90A0 #3EE08F #FF5A5A.
Vietnamese street mafia theme, stylized cartoon, humorous, not realistic, no real brands.
No text, no letters, no numbers, no logo, no watermark, no drop shadow.
```

Chèn dòng này vào đầu từng prompt dưới đây (tôi viết tắt là `[STYLE]`).

## NEGATIVE (dán kèm nếu tool hỗ trợ)

```
3d, photorealistic, smooth gradient, blur, glow bloom, anti-aliasing, checkerboard,
white background, text, letters, numbers, logo, watermark, real firearm, gore, blood,
drop shadow, rounded corners, perspective camera, isometric, multiple objects, sprite sheet,
grid of items, collage, mockup, phone frame, ui screen
```

---

# PHASE 1 — NỀN CẢNH (làm trước, ăn tiền nhất)

Khung dọc 9:19.5. Gen xong resize về **780×1688**, lưu `.png` (không alpha).
Mẹo cho mọi prompt nền: `bottom 25% darker and simple, no characters, no UI`.
Có thể dùng ảnh nền đầu tiên làm reference cho các nền sau:
"keep this exact palette, lighting and pixel density, now show ...".

| # | File | Bối cảnh | Dùng ở |
|---|---|---|---|
| 1 | `bg_alley.png` | Hẻm 12 ban đêm | Home / login |
| 2 | `bg_karaoke.png` | Quán karaoke | Nền tab Bang |
| 3 | `bg_market.png` | Chợ Hòa Bình | Nền tab Bản đồ |
| 4 | `bg_bridge.png` | Bến xe Miền Đông | Nền tab Quân |
| 5 | `bg_shop.png` | Chợ đen | Nền tab Chợ |
| 6 | `bg_brawl.png` | Sân chém (hẻm sau quán nhậu) | Màn trận |

### 1. `bg_alley.png`

```
[STYLE]
Vertical pixel art background for a mobile game, 9:19.5 portrait, Saigon back alley at night.
Layered parallax for a side-scrolling beat-em-up: far layer of dark apartment blocks with
lit windows, mid layer of corrugated metal walls, hanging power wires, karaoke neon signs
made of abstract glowing shapes with NO readable letters, air conditioners, laundry lines.
Near layer: plastic stools, beer crates, an old Wave motorbike parked, wet asphalt with
puddles reflecting pink and cyan neon.
Bottom 25% darker and simple, no characters, no UI, no text.
```

### 2. `bg_karaoke.png`

```
[STYLE]
Vertical pixel art background, 9:19.5 portrait, interior of a cheap Vietnamese karaoke bar
at night: small stage with microphone stand, velvet curtain, disco ball, plastic chairs,
beer crates, smoke haze, neon strips in pink and cyan with abstract glowing shapes and
NO readable letters. Layered depth: stage far, tables mid, floor near.
Bottom 25% darker and simple, no characters, no UI, no text.
```

### 3. `bg_market.png`

```
[STYLE]
Vertical pixel art background, 9:19.5 portrait, Vietnamese wet market at dusk:
corrugated tin roof stalls, hanging bare bulbs, baskets of vegetables, ice boxes,
butcher table with stylized goods, awnings in faded colors, wet concrete floor.
Warm gold light against the dark palette. Layered depth: stalls far, aisle mid, floor near.
Bottom 25% darker and simple, no characters, no UI, no text.
```

### 4. `bg_bridge.png`

```
[STYLE]
Vertical pixel art background, 9:19.5 portrait, Saigon bus station under a concrete
overpass at night: parked minibuses, ticket booths, metal benches, chain link fence,
street lamps, distant city glow, graffiti made of abstract shapes with NO readable letters.
Layered depth: overpass far, buses mid, cracked pavement near.
Bottom 25% darker and simple, no characters, no UI, no text.
```

### 5. `bg_shop.png`

```
[STYLE]
Vertical pixel art background, 9:19.5 portrait, cramped black-market pawn shop interior:
shelves of old watches, gold chains, a glass counter, locked metal cabinet, bare hanging
bulb, hanging plastic bags, stacks of cash bundles, a ceiling fan.
Green and cyan accent light, deep shadows. Layered depth: shelves far, counter mid, floor near.
Bottom 25% darker and simple, no characters, no UI, no text.
```

### 6. `bg_brawl.png`

```
[STYLE]
Vertical pixel art background, 9:19.5 portrait, empty fight yard behind a Vietnamese beer
pub at night: concrete ground, metal fence, stacked beer crates, dumped barrels, single
hanging bulb, neon spill from the pub door with abstract glowing shapes and NO readable
letters. Symmetrical composition with empty space in the middle for fighters.
Layered depth: fence far, crates mid, ground near with dust.
Bottom 25% darker and simple, no characters, no UI, no text.
```

---

# PHASE 2 — NHÂN VẬT & TRÙM

## 2A. Sprite võ sĩ (8 file)

Gen **1 nhân vật 1 ảnh**, không sheet. Khung dọc, gen 512×768 rồi resize về **64×96**
(tôi scale trong Flame). Nền trong suốt thật.

Quy ước chung cho cả 8 prompt:

```
[STYLE]
Single side-view beat-em-up character sprite, facing right, full body, feet touching the
bottom edge, centered, one character only, transparent background.
32x48 pixel proportions, chunky limbs, flat shading, 1px outline.
```

| File | Nhân vật | Tư thế |
|---|---|---|
| `player_idle.png` | Áo cyan | Đứng thủ, mã tấu cầm ngang |
| `player_walk.png` | Áo cyan | Bước tới, chân trước chân sau |
| `player_attack.png` | Áo cyan | Vung mã tấu chéo xuống |
| `player_hurt.png` | Áo cyan | Giật lùi, tay che mặt |
| `enemy_idle.png` | Áo hồng | Đứng thủ, ống tuýp |
| `enemy_walk.png` | Áo hồng | Bước tới |
| `enemy_attack.png` | Áo hồng | Vung ống tuýp ngang |
| `enemy_hurt.png` | Áo hồng | Giật lùi |

Ví dụ đầy đủ cho `player_idle.png` (các file khác đổi đúng 2 dòng cuối):

```
[STYLE]
Single side-view beat-em-up character sprite, facing right, full body, feet touching the
bottom edge, centered, one character only, transparent background.
32x48 pixel proportions, chunky limbs, flat shading, 1px outline.
Vietnamese street gangster, cyan tank top #00E5D0, rolled jeans, sandals, gold chain,
short slicked hair, confident smirk, holding a stylized cleaver at chest level.
Idle stance, weight on back foot, ready to fight. Exactly one character, nothing else.
```

Với `player_hurt.png` thêm: `leaning backward, one arm raised to block, grimace, no blood`.
Với `enemy_*` đổi thành: `pink shirt #FF2E63, bandana, holding a stylized metal pipe`.
Với `enemy_attack.png` thêm: `swinging the pipe horizontally, motion arc drawn as 2 flat pixel streaks`.

## 2B. Chân dung trùm (6 file)

Gen vuông, resize về **96×96** (tôi phóng to nearest trong UI). Nền trong suốt.
Khác nhau rõ ở tuổi / phụ kiện / biểu cảm để nhìn là phân biệt được.

Prompt gốc:

```
[STYLE]
Single bust portrait for a pixel game boss card, front view, head and shoulders,
centered, one character only, transparent background, 1px outline, flat shading.
Humorous stylized Vietnamese mafia boss, exaggerated cartoon proportions, not realistic,
no blood, no real brands.
```

| File | Trùm (chương) | Thêm vào prompt |
|---|---|---|
| `boss_chuong1.png` | Đầu Gấu Hẻm (Hẻm 12) | `young street thug, buzz cut, scar on eyebrow, tank top, gold tooth grin, cocky` |
| `boss_chuong2.png` | Bảo Kê Chợ (Chợ Hòa Bình) | `middle-aged market enforcer, straw hat, toothpick, rolled sleeves, fat gold chain, squint` |
| `boss_chuong3.png` | Trùm Karaoke (Karaoke Phượng Hoàng) | `slick showman boss, purple suit, sunglasses at night, microphone in hand, big smile` |
| `boss_chuong4.png` | Trùm Chợ Đêm (Chợ Đêm) | `night market boss, leather jacket, cigarette, half-shaved head, cold stare` |
| `boss_chuong5.png` | Bà Trùm Quận (Bến Xe Miền Đông) | `older woman boss, red ao dai, hair bun, jade bracelet, thin smile, fan in hand` |
| `boss_chuong6.png` | Ông Trùm Sài Gòn (Sài Gòn) | `old godfather, white suit, fedora, cane, thick moustache, calm dangerous eyes` |

---

# PHASE 2C — CHÂN DUNG NHÂN VẬT CHO UI

Phần này KHÁC sprite ở 2A: đây là **bán thân (bust)** để nhét vào card/avatar,
không phải sprite đứng đánh nhau. Gen vuông, resize về **96×96**, nền trong suốt.

Prompt gốc (dán trước, chỉ đổi phần mô tả nhân vật):

```
[STYLE]
Single character portrait for a pixel game card, front-facing bust, head and shoulders,
centered, one character only, transparent background, 1px black outline, flat shading,
chunky cartoon proportions, exaggerated expressive face, Vietnamese street mafia style,
not realistic, no blood, no real brands, no text.
```

## Avatar theo cấp bậc (6 file) → `client/assets/char/`

Dùng ở header home (thay ô số level) và bảng uy tín.

| File | Cấp | Thêm vào prompt |
|---|---|---|
| `char_rank_condo.png` | Con đỏ | `teenage parking boy, skinny, faded t-shirt, baseball cap, nervous side glance` |
| `char_rank_danem.png` | Đàn em | `early 20s street soldier, bomber jacket, thin gold chain, slicked hair, cocky smirk` |
| `char_rank_daica.png` | Đại ca | `30s boss, unbuttoned shirt, thick gold chain, eyebrow scar, toothpick in mouth` |
| `char_rank_bangtruong.png` | Băng trưởng | `40s gang leader, grey vest, gold rings, receding hairline, cold stare` |
| `char_rank_trumquan.png` | Trùm quận | `50s district boss, white shirt with vest, gold watch, grey hair, heavy beard` |
| `char_rank_ongtrum.png` | Ông trùm | `60s godfather, white suit, fedora, cane over shoulder, thick moustache, calm eyes` |

## Đàn em theo độ hiếm (3 file) → `client/assets/char/`

Dùng ở danh sách đàn em (tab Quân) và lúc mộ quân.

| File | Độ hiếm | Thêm vào prompt |
|---|---|---|
| `char_minion_thuong.png` | Thường | `ordinary young thug, plain t-shirt, blank clueless look` |
| `char_minion_hiem.png` | Hiếm | `veteran thug, leather jacket, cheek scar, sneaky grin` |
| `char_minion_dacbiet.png` | Đặc biệt | `elite enforcer, bandana over one eye, chain around neck, glowing eye, imposing` |

## Boss tuần (1 file) → `client/assets/char/`

Boss dùng chung 120.000 máu, không thuộc chương nào → phải nhìn "to hơn người".

```
[STYLE]
Single character portrait for a pixel game card, front-facing bust, head and shoulders,
centered, one character only, transparent background, 1px black outline, flat shading.
Massive intimidating Vietnamese crime lord, gold crown, heavy gold chains, rings on every
finger, cigar, huge shoulders filling the frame, small satisfied grin,
no blood, no real brands, no text.
```

Lưu: `boss_tuan.png` — 96×96.

## Icon kỹ năng đàn em (9 file) → `client/assets/skill/`

Vuông, resize **64×64**, nền trong suốt. Prompt gốc:

```
[STYLE]
Single pixel art game skill icon, 64x64, centered, one symbol only, transparent background,
chunky readable shape, 1px black outline, flat 3-color shading, no frame, no text.
```

| File | Kỹ năng | Thêm vào prompt |
|---|---|---|
| `skill_dao.png` | Dao Bén (+15% dmg) | `short cleaver blade with a sharp highlight glint` |
| `skill_maulieu.png` | Máu Liều | `single blood drop with two speed streaks, no gore spray` |
| `skill_trau.png` | Trâu Bò (+30 máu) | `front-facing buffalo head with curved horns` |
| `skill_ne.png` | Né Đòn | `leaning human silhouette with a motion arc passing behind` |
| `skill_chiemlen.png` | Chém Lén | `dagger stabbing from behind a shoulder silhouette, backstab angle` |
| `skill_momto.png` | Mồm To (+25 uy) | `megaphone with sound arcs, open mouth silhouette on the side` |
| `skill_satthu.png` | Sát Thủ | `curved assassin dagger crossed with a staring eye` |
| `skill_detu.png` | Đệ Tử Ruột | `two matching head silhouettes side by side, one slightly behind` |
| `skill_trumkhu.png` | Trùm Khu | `small crown on top of a knife stuck in the ground` |

## Icon vũ khí (4 file) → `client/assets/skill/`

Resize **48×48**, nền trong suốt. Vũ khí phải **stylized, không giống súng thật**
(README dặn tránh bị Google Play gắn cờ) — súng vẽ kiểu đồ chơi.

Prompt gốc:

```
[STYLE]
Single pixel art game item icon, 48x48, centered, one object only, transparent background,
side view, 1px black outline, flat shading, stylized cartoon, no text.
```

| File | Vũ khí | Thêm vào prompt |
|---|---|---|
| `wpn_matau.png` | Mã tấu | `short cleaver, worn wooden handle, chipped blade` |
| `wpn_pho.png` | Phớ | `long machete with a wrapped grip, slight curve` |
| `wpn_sung.png` | Súng lục | `chunky toy-like pistol, oversized barrel, orange tip, clearly cartoon` |
| `wpn_hangnong.png` | Hàng nóng | `short cartoon shotgun with a wide muzzle and brass shells nearby, toy proportions` |

---

# PHASE 2D — SPRITE SHEET ĐÁNH NHAU (trận cận chiến)

Chỉ **2 file**, mỗi file là 1 sheet lưới **4×4 ô = 16 ô vuông đều nhau**
(kích thước ảnh 1024×1024, mỗi ô 256×256). Tôi tự cắt thành 16 frame.
Nhân vật **LUÔN quay sang PHẢI** — bên địch code tự lật.

| File | Nhân vật |
|---|---|
| `sheet_fight_player.png` | đại ca nhà mình |
| `sheet_fight_enemy.png` | gã đàn em của trùm địch |

**Layout bắt buộc (theo hàng):**

| Hàng | Ô 1 | Ô 2 | Ô 3 | Ô 4 |
|---|---|---|---|---|
| 1 | chạy bước 1 | chạy bước 2 | chạy bước 3 | chạy bước 4 |
| 2 | đứng thở 1 | đứng thở 2 | vung đòn — giơ lùi | chém tới |
| 3 | trúng đòn ngửa lùi | ngã ngửa ra sau | nằm sẹp đất | ăn mừng giơ nắm đấm |
| 4 | cầm súng đứng 1 | cầm súng đứng 2 | giơ súng nhắm 2 tay | bắn — loé đầu nòng cam |

Prompt chung (dán nguyên, chỉ đổi dòng CHARACTER):

```
[STYLE]
Sprite sheet for a 2D side-view fighting game. A strict 4x4 grid of 16 equal
square cells (4 columns, 4 rows), image size 1024x1024, each cell 256x256.
ONE AND THE SAME character repeated in every cell, FULL BODY from head to toe,
feet touching the bottom edge of its cell, character centered in its cell,
always facing RIGHT, transparent background, 1px black outline, flat shading,
chunky cartoon proportions, Vietnamese street mafia style, not realistic,
no blood, no real brands, no text, no labels, no numbers, no grid lines,
no cell borders, no ground shadows, identical size and identical colors in
all 16 cells.

CHARACTER: young Vietnamese street gangster hero, black tank top, cyan
bandana tied on his head, dark jeans, cyan sneakers, holding a machete
in his right hand, small pistol tucked in his belt.

Row 1: four frames of the character RUNNING to the right, legs in alternating
stride poses, machete in hand.
Row 2: idle breathing pose (two frames), then attack windup pulling the
machete back, then attack strike swinging the machete forward with a white
motion swoosh.
Row 3: hurt recoil leaning backward, falling backward in mid-air, lying flat
on the ground defeated, victory pose with one fist raised.
Row 4: standing holding the pistol in one hand (two frames), aiming the
pistol with both hands, firing the pistol with a bright orange muzzle flash.
The pistol looks like a toy with a bright orange muzzle tip.
```

`sheet_fight_enemy.png` — chỉ đổi dòng CHARACTER thành:

```
CHARACTER: rival gang enforcer, black bomber jacket, red bandana on his head,
thick gold chain, dark pants, black boots, holding a machete in his right
hand, small pistol tucked in his belt.
```

Lưu ý: cùng 1 nhân vật ở cả 16 ô, cùng cỡ cùng màu — đây là yêu cầu quan
trọng nhất; nếu ra nhiều nhân vật khác nhau thì generate lại.

## PHASE 2E — BIẾN THỂ ĐÀN EM (đám đông khỏi giống nhau)

Cùng **đúng** layout 4×4 / 1024×1024 / 16 ô / quay sang PHẢI như PHASE 2D —
chỉ đổi dòng `CHARACTER`. Prompt chung giữ nguyên (dán y hệt khối ở trên),
thay dòng CHARACTER bằng một trong các dòng dưới đây.

| File | Nhân vật |
|---|---|
| `sheet_fight_m1.png` | thằng nhóc tóc dựng |
| `sheet_fight_m2.png` | gã béo hói |
| `sheet_fight_m3.png` | ông già khô |
| `sheet_fight_m4.png` | cô gái tóc đuôi ngựa |
| `sheet_fight_m5.png` | gã hoodie kính đen |
| `sheet_fight_m6.png` | gã tóc dreadlock |
| `sheet_fight_m7.png` | chú áo bà ba khăn rằn |
| `sheet_fight_m8.png` | gã cơ bắp xăm |

```
m1 CHARACTER: skinny teenage street kid, tall spiky black mohawk, white tank
top, torn dark jeans, cyan sneakers, thin silver chain, holding a machete in
his right hand, small toy pistol tucked in his belt.
```
```
m2 CHARACTER: heavyset bald enforcer, thick neck, dark grey tank top stretched
over a big belly, thick gold chain, black shorts, rubber sandals, holding a
machete in his right hand, small toy pistol tucked in his belt.
```
```
m3 CHARACTER: wiry old gangster, grey hair combed back, thin moustache, faded
olive button shirt, brown trousers, rubber sandals, holding a machete in his
right hand, small toy pistol tucked in his belt.
```
```
m4 CHARACTER: tough young woman, black ponytail, red bandana around her neck,
cropped denim jacket, dark leggings, black boots, holding a machete in her right
hand, small toy pistol tucked in her belt.
```
```
m5 CHARACTER: lanky guy in an oversized grey hoodie with the hood up, dark
sunglasses, baggy dark pants, worn sneakers, holding a machete in his right
hand, small toy pistol tucked in his belt.
```
```
m6 CHARACTER: stocky man with short black dreadlocks, flat-color patterned tank
top, cargo shorts, flip-flops, holding a machete in his right hand, small toy
pistol tucked in his belt.
```
```
m7 CHARACTER: middle-aged Vietnamese man in a dark blue ao ba ba shirt with
white buttons, red checkered scarf (khan ran) around his neck, rolled-up
trousers, bare feet, holding a machete in his right hand, small toy pistol
tucked in his belt.
```
```
m8 CHARACTER: muscular shirtless enforcer with simple flat tattoo shapes on his
shoulders (NO letters or symbols), dog tags, camo pants, jungle boots, holding
a machete in his right hand, small toy pistol tucked in his belt.
```

Lưu file vào `docs/raw/sheet_fight_m1.png` … `m8.png`, rồi cắt:

```bash
python3 tools/slice_fight_sheet.py docs/raw/sheet_fight_m1.png
```

Mỗi nhân vật ra **một** file `client/assets/fight/atlas_m1.png` … `atlas_m8.png`
(lưới 4×4 = đủ 16 frame trong 1 ảnh). Client nạp atlas và vẽ theo ô, nên không
có file rời từng frame. Chạy cả loạt:

```bash
for f in docs/raw/sheet_fight_m*.png; do python3 tools/slice_fight_sheet.py "$f"; done
```

---

# PHASE 3 — ICON

Gen mỗi icon 1 ảnh, vuông, resize về **32×32**, nền trong suốt thật.

Prompt gốc:

```
[STYLE]
Single pixel art game icon, 32x32, centered, one object only, transparent background,
chunky readable silhouette at small size, 1px black outline, flat 3-color shading.
No text, no letters, no frame, no badge.
```

| File | Icon | Thêm vào prompt |
|---|---|---|
| `icon_coin.png` | Tiền | `stack of three gold coins #FFC93C with a simple embossed circle, gold sparkle pixels` |
| `icon_uy.png` | Uy tín | `cyan #00E5D0 five-point star, hard bevel, no glow` |
| `icon_power.png` | Lực | `pink #FF2E63 clenched fist, side view` |
| `icon_crew.png` | Đàn em | `single cyan head silhouette with shoulders, small scar` |
| `icon_minion.png` | Lính đông | `three small cyan head silhouettes in a row, front one bigger` |
| `icon_flag.png` | Địa bàn | `territory flag on a short pole, red pennant, gold pole tip` |
| `icon_shield.png` | Khiên | `cyan shield with a light vertical bevel, dark inner line` |
| `icon_fire.png` | Độ nóng | `pink-orange flame, 2 flat color steps, no glow` |
| `icon_skull.png` | Boss | `off-white skull, empty eye sockets, no jaw teeth detail, cartoon not scary` |
| `icon_lock.png` | Khoá | `gold padlock, closed shackle, keyhole as 2 pixels` |
| `icon_plus.png` | Mộ quân | `green #3EE08F thick plus sign, hard bevel` |
| `icon_heart.png` | Máu | `red #FF5A5A heart with a light pink highlight pixel` |

## Nav icon (5 file)

Giữ **cùng silhouette style** với bộ trên. Prompt gốc:

```
[STYLE]
Single pixel art bottom-navigation icon, 32x32, centered, one object only,
solid silhouette with 1px black outline, transparent background,
same weight as a game UI icon set, no text, no badge, no frame.
```

| File | Tab | Thêm vào prompt |
|---|---|---|
| `nav_home.png` | Bang | `storefront with awning and a small door, cyan accents` |
| `nav_map.png` | Bản đồ | `folded street map with a location pin, cyan accents` |
| `nav_crew.png` | Quân | `three tiny soldier silhouettes standing in a row` |
| `nav_shop.png` | Chợ | `shop bag with a flame stamped on it, gold accents` |
| `nav_gang.png` | Băng | `small trophy cup with a star, pink accents` |

---

# PHASE 4 — UI KIT (tuỳ chọn, làm sau)

UI hiện tại đã vẽ panel/button bằng code (`NeonPanel`, `PrimaryButton`) nên **chưa cần**
mấy file này. Chỉ gen khi muốn nút/khung có texture pixel thật.

Gen **1 món 1 ảnh** cho sạch, rồi tôi dùng `BoxFit` / 9-slice.

| File | Kích thước | Prompt thêm |
|---|---|---|
| `panel_dark.png` | 48×48 | `single 9-slice panel, 8px uniform border, flat empty #161922 center, border #262B36` |
| `panel_cyan.png` | 48×48 | như trên, border `#00E5D0` |
| `panel_gold.png` | 48×48 | như trên, border `#FFC93C` |
| `panel_red.png` | 48×48 | như trên, border `#FF5A5A` |
| `panel_pink.png` | 48×48 | như trên, border `#FF2E63` |
| `btn_normal.png` | 64×28 | `single button, flat #FF2E63 fill, bevel top-left light, bottom-right dark` |
| `btn_pressed.png` | 64×28 | `same button, darker fill, inverted bevel, content shifted 2px down` |
| `btn_disabled.png` | 64×28 | `same button, desaturated gray, low contrast` |
| `chip_dark.png` | 48×24 | `single small pill-less rectangular chip, dark fill` |
| `chip_cyan.png` | 48×24 | chip, cyan border |
| `chip_gold.png` | 48×24 | chip, gold border |
| `bar_frame.png` | 96×16 | `empty horizontal bar frame, black outline, dark inset` |
| `bar_fill_hp.png` | 96×12 | `solid red-orange fill strip, 1px top highlight` |
| `bar_fill_xp.png` | 96×12 | `solid cyan fill strip, 1px top highlight` |
| `card_frame.png` | 64×64 | `square item card frame, 8px border, empty center` |
| `dialog_frame.png` | 96×96 | `9-slice dialogue box, 12px border, empty center` |

Với mọi prompt UI kit phải thêm đuôi: `centered, isolated, nothing else in frame,
no text, no icons inside the panel, intact corner pixels, uniform border width`.

---

# Checklist

- [x] 6 nền PHASE 1 → đã gắn vào UI (`client/assets/scene/*.webp`)
- [ ] 8 sprite PHASE 2A
- [~] 6 trùm PHASE 2B — đã có 1–5 (`client/assets/char/`), còn thiếu `boss_chuong6`
- [ ] 2 sprite sheet đánh nhau PHASE 2D → `tools/slice_fight_sheet.py` tự cắt
- [ ] 6 avatar cấp bậc PHASE 2C
- [ ] 3 chân dung đàn em PHASE 2C
- [ ] 1 boss tuần PHASE 2C
- [ ] 9 icon kỹ năng PHASE 2C
- [ ] 4 icon vũ khí PHASE 2C
- [ ] 12 icon PHASE 3
- [ ] 5 nav icon PHASE 3
- [ ] 16 UI kit PHASE 4 (tuỳ chọn)

Tổng bắt buộc: **60 file**. Có UI kit: 76.

Sau khi có ảnh, tôi sẽ làm: thêm `assets` vào `pubspec.yaml`, dựng `AppIcon`
thay `IconData`, load nền + sprite vào `AlleyGame`/`BrawlGame`, trùm vào màn
campaign, nav icon vào `shell.dart`.
