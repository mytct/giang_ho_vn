package main

import (
	"math"
	"strconv"
	"time"
)

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

// UpkeepPerSec: đàn em và tướng ăn lương tiền mỗi giây; lính ăn hàng.
func (p *Player) UpkeepPerSec() float64 {
	return float64(p.Crew)*1.5 + float64(len(p.Generals))*3
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
	goodsPerOwned     = 0.5
	minionGoodsPerSec = 0.1
)

// WorkDef là công trình xây trong thành (giữ trọn 6 ô một quận).
type WorkDef struct {
	ID       string
	Name     string
	Desc     string
	Icon     string
	MaxLevel int
	BaseCost int64
}

var WorkDefs = []WorkDef{
	{"cho", "Chợ đen", "+6 hàng/giây", "C", 3, 1500},
	{"trai", "Trại lính", "+25 lính tối đa, +5 phòng thủ mỗi ô", "T", 3, 2000},
	{"song", "Sòng bài", "+8% thu nhập toàn bộ", "S", 3, 2500},
}

func WorkByID(id string) *WorkDef {
	for i := range WorkDefs {
		if WorkDefs[i].ID == id {
			return &WorkDefs[i]
		}
	}
	return nil
}

func WorkCost(def WorkDef, level int) int64 {
	return def.BaseCost * int64(level+1) * int64(level+1)
}

// CityHeld: giữ đủ 12 quận của một tỉnh thì tỉnh thành "thành" của mình.
func (p *Player) CityHeld(province int) bool {
	return province >= 0 && province < len(DistrictNames) &&
		p.DistrictCount[province] >= DistrictSize
}

// HoldsDistrict: có ít nhất 1 quận trong tỉnh (Hồ Chí Minh là nhà, luôn làm ăn được).
func (p *Player) HoldsDistrict(province int) bool {
	if province < 0 || province >= len(DistrictNames) {
		return false
	}
	return province == HomeProvince || p.DistrictCount[province] > 0
}

func (p *Player) WorkLevel(province int, id string) int {
	return p.Works[province][id]
}

// workSum: chỉ công trình ở tỉnh còn giữ đất mới có tác dụng.
func (p *Player) workSum(id string) int {
	total := 0
	for d := range DistrictNames {
		if p.HoldsDistrict(d) {
			total += p.WorkLevel(d, id)
		}
	}
	return total
}

func (p *Player) GoodsRate() float64 {
	return goodsPerOwned*float64(p.OwnedCount()) + 6*float64(p.workSum("cho"))
}

func (p *Player) GoodsUpkeepPerSec() float64 {
	return float64(p.MinionHealthy()) * minionGoodsPerSec
}

func (p *Player) MinionCap() int { return MaxMinions + 25*p.workSum("trai") }

func (p *Player) WorkIncomeMul() float64 { return 1 + 0.08*float64(p.workSum("song")) }

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

func (p *Player) GuardedMinions() int {
	total := 0
	for _, n := range p.MinionGuards {
		total += n
	}
	return total
}

// AvailableMinions: lính còn đi chém được (trừ số đang canh giữ).
func (p *Player) AvailableMinions() int {
	n := p.MinionHealthy() - p.GuardedMinions()
	if n < 0 {
		return 0
	}
	return n
}

// clampGuards trả quân về khi lính chết/thương hoặc đàn em bỏ đi.
func (p *Player) clampGuards() {
	over := p.GuardedMinions() - p.MinionHealthy()
	for id, n := range p.MinionGuards {
		if over <= 0 {
			break
		}
		cut := min(n, over)
		p.MinionGuards[id] = n - cut
		over -= cut
	}
	over = p.GuardsTotal() - p.Crew
	for id, n := range p.Guards {
		if over <= 0 {
			break
		}
		cut := min(n, over)
		p.Guards[id] = n - cut
		over -= cut
	}
}

// MinionPower: lính khỏe đóng góp 1 lực mỗi 2 đứa, cộng vũ khí đang cầm.
// Lính đang canh giữ đất không đi chém.
func (p *Player) MinionPower() int {
	h := p.AvailableMinions()
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

// 33 tỉnh/thành (dữ liệu 2025), mỗi tỉnh 12 quận.
const DistrictSize = 12

// DistrictNames/HomeProvince dựng từ Provinces (provinces.go).
var DistrictNames []string
var HomeProvince int

func init() {
	for i, p := range Provinces {
		DistrictNames = append(DistrictNames, p.Name)
		if p.Name == "Hồ Chí Minh" {
			HomeProvince = i
		}
	}
}

func DistrictOf(id int) int { return id / DistrictSize }

func HomeRegion() int { return Provinces[HomeProvince].Region }

func ProvinceOf(id int) string {
	p := DistrictOf(id)
	if p < 0 || p >= len(Provinces) {
		return ""
	}
	return Provinces[p].Name
}

func RegionOfProvince(province int) int {
	if province < 0 || province >= len(Provinces) {
		return 0
	}
	return Provinces[province].Region
}

type Territory struct {
	ID          int    `json:"id"`
	ProvinceID  int    `json:"provinceId"`
	Province    string `json:"province"`
	Region      int    `json:"region"`
	Level       int    `json:"level"`
	OwnerGangID string `json:"ownerGangId"`
	Name        string `json:"name"`
	OwnerID     string `json:"ownerId"`
	OwnerName   string `json:"ownerName"`
	Tax         int64  `json:"tax"`
	Defense     int    `json:"defense"`
	// Chủ mới phải giữ đủ contestWindow mới vững; trước đó chủ cũ đánh lại dễ hơn.
	PrevOwnerID string `json:"prevOwnerId"`
	ContestedAt int64  `json:"contestedUntil"`
}

func (t *Territory) Contested(now time.Time) bool { return t.ContestedAt > now.Unix() }

// npcOwnerFor: rải vài quận cho băng NPC để có đất mà đánh.
func npcOwnerFor(province, slot int) string {
	switch (province*3 + slot) % 9 {
	case 0:
		return "npc:ran"
	case 3:
		return "npc:ca"
	case 5:
		return "npc:o"
	case 7:
		return "npc:chuot"
	}
	return ""
}

func NewTerritories() []*Territory {
	out := make([]*Territory, 0, len(Provinces)*DistrictSize)
	for pi, prov := range Provinces {
		for k := 0; k < DistrictSize; k++ {
			t := &Territory{
				ID:         pi*DistrictSize + k,
				ProvinceID: pi,
				Province:   prov.Name,
				Region:     prov.Region,
				Name:       "Quận " + strconv.Itoa(k+1),
				Tax:        16 + prov.Tax/4 + int64(k%4)*3,
				Defense:    45 + k*3 + prov.Defense/12,
			}
			if g := npcOwnerFor(pi, k); g != "" {
				t.OwnerID = g
				t.OwnerName = npcGangs[g]
			}
			out = append(out, t)
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
	return 4 + rankLevel*4
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

// RegionMul: cơ sở của vùng ăn theo số quận đang giữ (cap 1.5),
// mỗi tỉnh giữ trọn trong vùng +10%.
func (p *Player) RegionMul(region int) float64 {
	if region < 0 || region >= len(RegionNames) {
		return 1
	}
	m := 1 + 0.1*float64(p.RegionCount[region])
	if m > 1.5 {
		m = 1.5
	}
	full := 0
	for i := range Provinces {
		if Provinces[i].Region == region && p.CityHeld(i) {
			full++
		}
	}
	return m * (1 + 0.1*float64(full))
}

// HoldsRegion: vùng của Hồ Chí Minh là nhà, luôn làm ăn được; vùng khác cần 1 quận.
func (p *Player) HoldsRegion(region int) bool {
	if region < 0 || region >= len(RegionNames) {
		return false
	}
	return region == HomeRegion() || p.RegionCount[region] > 0
}

func (p *Player) BizLevel(region int, id string) int { return p.Biz[region][id] }

func (p *Player) HasBiz(id string) bool {
	for r := range RegionNames {
		if p.BizLevel(r, id) > 0 {
			return true
		}
	}
	return false
}

func (p *Player) BusinessRate(def BusinessDef, region int) float64 {
	if !p.HoldsRegion(region) {
		return 0
	}
	lvl := p.BizLevel(region, def.ID)
	if lvl == 0 {
		return 0
	}
	racket := 1 + 0.15*float64(p.Racket[def.ID])
	return float64(def.Base) * float64(lvl) * (1 + float64(p.Uy)/4000) *
		p.RegionMul(region) * racket
}

func (p *Player) RatePerSec() float64 {
	total := 0.0
	for r := range RegionNames {
		for _, def := range BusinessDefs {
			total += p.BusinessRate(def, r)
		}
	}
	if p.Items["wave"] {
		total *= 1.08
	}
	total *= p.WorkIncomeMul()
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
