package main

import "math"

type Rank struct {
	Level int
	Name  string
	Uy    int64
}

var Ranks = []Rank{
	{0, "Con đỏ", 0},
	{1, "Đàn em", 500},
	{2, "Đại ca", 2000},
	{3, "Băng trưởng", 6000},
	{4, "Trùm quận", 15000},
	{5, "Ông trùm", 30000},
}

type Weapon struct {
	Name string `json:"name"`
	Dmg  int    `json:"dmg"`
	Cost int64  `json:"cost"`
}

var Weapons = []Weapon{
	{"Mã tấu", 12, 0},
	{"Phớ", 22, 6000},
	{"Súng lục", 38, 30000},
	{"Hàng nóng", 60, 150000},
}

type MissionDef struct {
	ID     string
	Title  string
	Desc   string
	Kind   string
	Target int
	Money  int64
	Uy     int64
}

var MissionDefs = []MissionDef{
	{"muaso", "Mở hàng", "Nâng cấp bất kỳ cơ sở nào 1 lần", "upgrade", 1, 500, 20},
	{"quan", "Có đàn em", "Mộ 1 đàn em", "recruit", 1, 800, 30},
	{"chiem", "Ra tay", "Thắng 1 trận chiếm địa bàn", "win", 1, 1200, 60},
	{"thunhap", "Tiền về", "Kiếm 5.000đ từ cơ sở", "earn", 5000, 600, 40},
	{"hangnong", "Lên đồ", "Mua 1 món vũ khí mới", "weapon", 1, 2000, 100},
	{"bangdang", "Cắm cờ", "Giữ 3 địa bàn cùng lúc", "own", 3, 3000, 150},
}

type SkillDef struct {
	ID         string
	Name       string
	Desc       string
	Rarity     string
	Weight     int
	DmgMul     float64
	HpAdd      int
	CritEvery  int
	DodgeEvery int
	FirstHitX2 bool
	UyBonus    int64
}

var SkillDefs = []SkillDef{
	{"dao", "Dao Bén", "+15% sát thương", "Thường", 22, 0.15, 0, 0, 0, false, 0},
	{"maulieu", "Máu Liều", "Đòn hiểm 2 lượt/lần", "Thường", 20, 0, 0, 2, 0, false, 0},
	{"trau", "Trâu Bò", "+30 máu", "Thường", 20, 0, 30, 0, 0, false, 0},
	{"ne", "Né Đòn", "Mỗi 4 đòn né 1", "Thường", 16, 0, 0, 0, 4, false, 0},
	{"chiemlen", "Chém Lén", "Đòn đầu x2 sát thương", "Hiếm", 10, 0, 0, 0, 0, true, 0},
	{"momto", "Mồm To", "Thắng +25 uy", "Hiếm", 8, 0, 0, 0, 0, false, 25},
	{"satthu", "Sát Thủ", "+25% sát thương, đòn hiểm 2 lượt/lần", "Đặc biệt", 2, 0.25, 0, 2, 0, false, 0},
	{"detu", "Đệ Tử Ruột", "+20% sát thương, +40 máu", "Đặc biệt", 2, 0.20, 40, 0, 0, false, 0},
	{"trumkhu", "Trùm Khu", "+50 máu, né mỗi 3 đòn", "Đặc biệt", 1, 0, 50, 0, 3, false, 0},
}

func SkillByID(id string) *SkillDef {
	for i := range SkillDefs {
		if SkillDefs[i].ID == id {
			return &SkillDefs[i]
		}
	}
	return nil
}

type SkillEffects struct {
	DmgMul     float64
	HpAdd      int
	CritEvery  int
	DodgeEvery int
	FirstHitX2 bool
	UyBonus    int64
}

func (e *SkillEffects) merge(def *SkillDef) {
	e.DmgMul += def.DmgMul
	e.HpAdd += def.HpAdd
	e.UyBonus += def.UyBonus
	e.FirstHitX2 = e.FirstHitX2 || def.FirstHitX2
	if def.CritEvery > 0 && (e.CritEvery == 0 || def.CritEvery < e.CritEvery) {
		e.CritEvery = def.CritEvery
	}
	if def.DodgeEvery > 0 && (e.DodgeEvery == 0 || def.DodgeEvery < e.DodgeEvery) {
		e.DodgeEvery = def.DodgeEvery
	}
}

func (p *Player) SkillEffects() SkillEffects {
	var e SkillEffects
	for _, id := range p.CrewSkills {
		if def := SkillByID(id); def != nil {
			e.merge(def)
		}
	}
	return e
}

// AllEffects: kỹ năng đàn em + tướng, dùng chung cho mọi trận.
func (p *Player) AllEffects() SkillEffects {
	e := p.SkillEffects()
	for _, g := range p.Generals {
		for _, id := range []string{g.SkillA, g.SkillB} {
			if def := SkillByID(id); def != nil {
				e.merge(def)
			}
		}
	}
	return e
}

func (p *Player) GeneralPower() int {
	total := 0
	for _, g := range p.Generals {
		total += 6 + g.Level*3
	}
	return total
}

func (p *Player) GeneralHP() int {
	total := 0
	for _, g := range p.Generals {
		total += 20 + g.Level*5
	}
	return total
}

// UpkeepPerSec: quân và tướng ăn lương mỗi giây, ăn hết tiền thì bỏ đi.
func (p *Player) UpkeepPerSec() float64 {
	return float64(p.Crew)*1.5 + float64(p.MinionHealthy())*0.3 +
		float64(len(p.Generals))*3
}

type ItemDef struct {
	ID    string
	Name  string
	Desc  string
	Cost  int64
	Emoji string
}

var ItemDefs = []ItemDef{
	{"wave", "Xe Wave độ", "+8% thu nhập từ cơ sở", 5000, "W"},
	{"chain", "Dây chuyền vàng", "+5% uy khi thắng trận", 8000, "C"},
	{"watch", "Đồng hồ đểu", "+10% tiền cướp được", 15000, "D"},
}

func ItemByID(id string) *ItemDef {
	for i := range ItemDefs {
		if ItemDefs[i].ID == id {
			return &ItemDefs[i]
		}
	}
	return nil
}

const (
	MaxMinions        = 500
	minionRecruitBase = 120
	minionHealCost    = 15
)

type MinionGearDef struct {
	ID    string
	Name  string
	Desc  string
	Cost  int64
	Power int
}

var MinionGearDefs = []MinionGearDef{
	{"dao", "Dao phay", "+1 lực mỗi lính cầm", 150, 1},
	{"kiem", "Kiếm Nhật", "+2 lực mỗi lính cầm", 400, 2},
}

func MinionGearByID(id string) *MinionGearDef {
	for i := range MinionGearDefs {
		if MinionGearDefs[i].ID == id {
			return &MinionGearDefs[i]
		}
	}
	return nil
}

func (p *Player) MinionHealthy() int {
	h := p.Minions - p.Wounds
	if h < 0 {
		return 0
	}
	return h
}

// MinionPower: lính khỏe đóng góp 1 lực mỗi 2 đứa, cộng vũ khí đang cầm.
func (p *Player) MinionPower() int {
	h := p.MinionHealthy()
	if h == 0 {
		return 0
	}
	daos := p.Gear["dao"]
	if daos > h {
		daos = h
	}
	kiems := p.Gear["kiem"]
	if kiems > h-daos {
		kiems = h - daos
	}
	return h/2 + daos + kiems*2
}

func (p *Player) MinionRecruitCost(count int) int64 {
	per := int64(minionRecruitBase + p.Minions/8)
	return per * int64(count)
}

func (p *Player) MinionHealCost(count int) int64 {
	return int64(count) * minionHealCost
}

type BusinessDef struct {
	ID     string
	Name   string
	Icon   string
	Base   int64
	Unlock int
}

var BusinessDefs = []BusinessDef{
	{"karaoke", "Karaoke Phượng Hoàng", "K", 10, 0},
	{"matxa", "Matxa Bình Dân", "M", 8, 0},
	{"baixe", "Bãi Giữ Xe", "B", 4, 0},
	{"nhau", "Quán Nhậu Cô Ba", "N", 6, 1},
	{"doxe", "Xưởng Độ Xe", "X", 18, 2},
	{"sanchim", "Sân Chim", "S", 40, 3},
}

// 24 ô chia 4 quận, mỗi quận 6 ô liền nhau.
const DistrictSize = 6

var DistrictNames = []string{"Hẻm 12", "Chợ Hòa Bình", "Bến Xe", "Sài Gòn"}

func DistrictOf(id int) int { return id / DistrictSize }

type Territory struct {
	ID          int    `json:"id"`
	Level       int    `json:"level"`
	OwnerGangID string `json:"ownerGangId"`
	Name        string `json:"name"`
	OwnerID     string `json:"ownerId"`
	OwnerName   string `json:"ownerName"`
	Tax         int64  `json:"tax"`
	Defense     int    `json:"defense"`
}

func NewTerritories() []*Territory {
	type def struct {
		name    string
		owner   string
		ownerID string
		tax     int64
		def     int
	}
	defs := []def{
		{"Hẻm 12", "", "", 20, 55},
		{"Chợ Hòa Bình", "Băng Chuột Cống", "npc:chuot", 34, 80},
		{"Bến Xe Miền Đông", "Băng Cá Sấu", "npc:ca", 48, 110},
		{"Karaoke Phượng Hoàng", "", "", 26, 70},
		{"Quán Cô Ba", "", "", 22, 60},
		{"Hẻm 47", "Băng Chuột Cống", "npc:chuot", 30, 75},
		{"Xóm Liều", "Băng Rắn Độc", "npc:ran", 40, 95},
		{"Cầu Đen", "", "", 24, 65},
		{"Chợ Đêm", "Băng Cá Sấu", "npc:ca", 52, 120},
		{"Bãi Giữ Xe", "", "", 18, 50},
		{"Tiệm Sửa Xe", "Băng Ó Đen", "npc:o", 36, 88},
		{"Ngã Tư Cá Lóc", "", "", 28, 72},
		{"Khu Ổ Chuột", "Băng Chuột Cống", "npc:chuot", 42, 100},
		{"Quán Nhậu Số 7", "", "", 20, 58},
		{"Hẻm Cụt", "Băng Ó Đen", "npc:o", 32, 82},
		{"Chung Cư Cũ", "", "", 25, 68},
		{"Bến Phà", "Băng Cá Sấu", "npc:ca", 55, 125},
		{"Chợ Cá", "", "", 30, 78},
		{"Karaoke Bình Dân", "Băng Rắn Độc", "npc:ran", 44, 105},
		{"Sòng Bạc", "Băng Rắn Độc", "npc:ran", 70, 150},
		{"Xưởng In", "", "", 27, 74},
		{"Bãi Rác", "Băng Chuột Cống", "npc:chuot", 38, 92},
		{"Cầu Vượt", "Băng Ó Đen", "npc:o", 46, 115},
		{"Sân Bóng", "", "", 23, 62},
	}
	out := make([]*Territory, len(defs))
	for i, d := range defs {
		out[i] = &Territory{
			ID: i, Name: d.name, OwnerID: d.ownerID,
			OwnerName: d.owner, Tax: d.tax, Defense: d.def,
		}
	}
	return out
}

func RankFor(uy int64) Rank {
	r := Ranks[0]
	for _, v := range Ranks {
		if uy >= v.Uy {
			r = v
		}
	}
	return r
}

func NextRank(uy int64) *Rank {
	for _, v := range Ranks {
		if uy < v.Uy {
			return &v
		}
	}
	return nil
}

func (p *Player) Weapon() Weapon { return Weapons[p.WeaponIdx] }

func (p *Player) OwnedCount() int { return len(p.Owned) }

func (p *Player) TerritoryMultiplier() float64 {
	m := 1 + 0.1*float64(p.OwnedCount())
	if m > 1.5 {
		return 1.5
	}
	return m
}

func MaxTerritories(rankLevel int) int {
	return 2 + rankLevel*2
}

func TerritoryUpgradeCost(level int) int64 {
	return int64(600 * (level + 1) * (level + 1))
}

type ChapterDef struct {
	Title       string
	Desc        string
	BossName    string
	BossPower   int
	NeedOwned   int
	NeedUy      int64
	RewardMoney int64
	RewardUy    int64
	RewardXP    int64
}

var Chapters = []ChapterDef{
	{"Hẻm 12", "Chiếm 1 địa bàn đầu tiên", "Đầu Gấu Hẻm", 40, 1, 0, 800, 20, 50},
	{"Chợ Hòa Bình", "Giữ 2 ô và có 300 uy", "Bảo Kê Chợ", 80, 2, 300, 2000, 50, 80},
	{"Karaoke Phượng Hoàng", "Giữ 3 ô và có 800 uy", "Trùm Karaoke", 130, 3, 800, 4000, 100, 120},
	{"Chợ Đêm", "Giữ 4 ô và có 2.000 uy", "Trùm Chợ Đêm", 200, 4, 2000, 8000, 200, 180},
	{"Bến Xe Miền Đông", "Giữ 6 ô và có 5.000 uy", "Bà Trùm Quận", 300, 6, 5000, 15000, 400, 260},
	{"Sài Gòn", "Giữ 8 ô và có 12.000 uy", "Ông Trùm Sài Gòn", 450, 8, 12000, 30000, 800, 400},
}

func (p *Player) BusinessRate(def BusinessDef) float64 {
	lvl := p.Levels[def.ID]
	if lvl == 0 {
		return 0
	}
	racket := 1 + 0.15*float64(p.Racket[def.ID])
	return float64(def.Base) * float64(lvl) * (1 + float64(p.Uy)/4000) *
		p.TerritoryMultiplier() * (1 + p.DistrictBonus) * racket
}

func (p *Player) RatePerSec() float64 {
	total := 0.0
	for _, def := range BusinessDefs {
		total += p.BusinessRate(def)
	}
	if p.Items["wave"] {
		total *= 1.08
	}
	total *= 1 - p.HeatPenalty()
	return total
}

func (p *Player) Power() int {
	r := RankFor(p.Uy)
	return p.Weapon().Dmg + p.Crew*6 + (r.Level+1)*10 + int(p.Uy/300) +
		p.BonusDmg() + p.BonusHP()/10 + p.MinionPower() + p.GeneralPower()
}

func UpgradeCost(def BusinessDef, level int) int64 {
	if level <= 0 {
		return 300
	}
	return int64(math.Round(300 * math.Pow(float64(level), 2) * (1 + 0.15*float64(level))))
}

func RecruitCost(crew int) int64 {
	return int64(math.Round(2000 * math.Pow(float64(crew+1), 1.4)))
}

func (p *Player) RosterUpgradeCost() int64 {
	if p.WeaponIdx+1 >= len(Weapons) {
		return 0
	}
	return Weapons[p.WeaponIdx+1].Cost
}
