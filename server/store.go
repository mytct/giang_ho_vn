package main

import (
	"crypto/rand"
	"encoding/hex"
	"errors"
	"fmt"
	mrand "math/rand"
	"sort"
	"strings"
	"sync"
	"time"
	"unicode/utf8"
)

const offlineCap = 8 * time.Hour

type Player struct {
	ID            string
	Name          string
	Money         int64
	Uy            int64
	Level         int
	XP            int64
	Points        int
	Stats         map[string]int
	WeaponIdx     int
	Crew          int
	CrewSkills    []string
	Levels        map[string]int
	Owned         map[int]bool
	Missions      map[string]int
	Claimed       map[string]bool
	GangID        string
	ShieldUntil   time.Time
	DailyDay      string
	Daily         map[string]int
	DailyClaimed  map[string]bool
	Earned        int64
	Inbox         []InboxMsg
	RevengeTarget string
	RevengeUntil  time.Time
	Contract      *Contract
	Items         map[string]bool
	SeasonKey     string
	SeasonUy      int64
	Defenses      []DefenseRecord
	Heat          int
	HeatAt        time.Time
	Bounty        int64
	Guards        map[int]int
	Minions       int
	Wounds        int
	Gear          map[string]int
	WoundAt       time.Time
	Formation     string
	LandIncome    float64
	Prestige      int
	Chapter       int
	LastAccrual   time.Time
	LastBrawl     time.Time
	Racket        map[string]int
	Generals      []General
	DevUnlimited  bool
	UpkeepMsgAt   time.Time
	DistrictCount [4]int
	DistrictHeld  int
	DistrictBonus float64
}

// General là tướng lĩnh: mỗi slot +lực, +máu, 2 kỹ năng; thua trận có thể chết.
type General struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Level  int    `json:"level"`
	SkillA string `json:"skillA"`
	SkillB string `json:"skillB"`
}

type GangMsg struct {
	ID   string `json:"id"`
	At   int64  `json:"at"`
	Name string `json:"name"`
	Role string `json:"role"`
	Text string `json:"text"`
}

type GangLog struct {
	At   int64  `json:"at"`
	Text string `json:"text"`
}

type Gang struct {
	ID                  string
	Name                string
	LeaderID            string
	Members             []string
	Officers            []string
	Chat                []GangMsg
	Log                 []GangLog
	Wars                map[string]time.Time
	Allies              map[string]time.Time
	TributeTo           string
	Treasury            int64
	WarScore            int
	WarDay              string
	WarSettledDay       string
	Level               int
	BoostUntil          time.Time
	ShieldCooldownUntil time.Time
	WarCooldownUntil    time.Time
	CreatedAt           time.Time
}

func (g *Gang) pruneRelations(now time.Time) {
	for id, until := range g.Wars {
		if !until.After(now) {
			delete(g.Wars, id)
			if cd := until.Add(warCooldown); cd.After(g.WarCooldownUntil) {
				g.WarCooldownUntil = cd
			}
		}
	}
	for id, until := range g.Allies {
		if !until.After(now) {
			delete(g.Allies, id)
		}
	}
}

func (g *Gang) atWar(now time.Time, id string) bool {
	g.pruneRelations(now)
	_, ok := g.Wars[id]
	return ok
}

func (g *Gang) allied(now time.Time, id string) bool {
	g.pruneRelations(now)
	_, ok := g.Allies[id]
	return ok
}

type InboxMsg struct {
	ID           string `json:"id"`
	Text         string `json:"text"`
	Kind         string `json:"kind"`
	At           int64  `json:"at"`
	FromName     string `json:"fromName"`
	TerritoryID  int    `json:"territoryId"`
	BattleID     string `json:"battleId"`
	RevengeUntil int64  `json:"revengeUntil"`
	Read         bool   `json:"read"`
}

type Contract struct {
	ID          string
	Title       string
	Desc        string
	Kind        string
	Target      int
	Deposit     int64
	RewardMoney int64
	RewardUy    int64
	Starts      int64
	EndsAt      time.Time
}

type DefenseRecord struct {
	ID            string      `json:"id"`
	At            int64       `json:"at"`
	AttackerName  string      `json:"attackerName"`
	TerritoryID   int         `json:"territoryId"`
	TerritoryName string      `json:"territoryName"`
	Result        BrawlResult `json:"result"`
}

type GuardSlot struct {
	TerritoryID int    `json:"territoryId"`
	Name        string `json:"name"`
	Count       int    `json:"count"`
	Tax         int64  `json:"tax"`
}

type MinionGearView struct {
	ID    string `json:"id"`
	Name  string `json:"name"`
	Desc  string `json:"desc"`
	Cost  int64  `json:"cost"`
	Power int    `json:"power"`
	Owned int    `json:"owned"`
}

type ContractView struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Desc        string `json:"desc"`
	Kind        string `json:"kind"`
	Target      int    `json:"target"`
	Progress    int    `json:"progress"`
	Deposit     int64  `json:"deposit"`
	RewardMoney int64  `json:"rewardMoney"`
	RewardUy    int64  `json:"rewardUy"`
	Remaining   int64  `json:"remaining"`
	Active      bool   `json:"active"`
	Complete    bool   `json:"complete"`
}

type BossRow struct {
	Name   string `json:"name"`
	Damage int64  `json:"damage"`
}

type BossView struct {
	Week     string    `json:"week"`
	HP       int64     `json:"hp"`
	MaxHP    int64     `json:"maxHp"`
	MyDamage int64     `json:"myDamage"`
	Tickets  int       `json:"tickets"`
	Defeated bool      `json:"defeated"`
	Top      []BossRow `json:"top"`
}

type CasinoResult struct {
	Roll   []int `json:"roll"`
	Sum    int   `json:"sum"`
	Win    bool  `json:"win"`
	Payout int64 `json:"payout"`
}

type BossHitResult struct {
	Damage   int64 `json:"damage"`
	Reward   int64 `json:"reward"`
	Uy       int64 `json:"uy"`
	BossHP   int64 `json:"bossHp"`
	Defeated bool  `json:"defeated"`
}

type Boss struct {
	Week   string
	HP     int64
	MaxHP  int64
	Damage map[string]int64
}

const (
	gangMaxMembers     = 10
	gangCreateCost     = 2000
	warDuration        = 30 * time.Minute
	lossShield         = 30 * time.Minute
	warCooldown        = 30 * time.Minute
	shieldCooldown     = 4 * time.Hour
	maxTributesPerGang = 2
)

// Băng NPC sống: mất đất thì kéo quân đòi lại.
type npcRaid struct {
	GangID      string
	TargetID    string
	TerritoryID int
	At          time.Time
}

var npcGangs = map[string]string{
	"npc:ran":   "Băng Rắn Độc",
	"npc:ca":    "Băng Cá Sấu",
	"npc:o":     "Băng Ó Đen",
	"npc:chuot": "Băng Chuột Cống",
}

var npcPower = map[string]int{
	"npc:ran": 200, "npc:ca": 170, "npc:o": 160, "npc:chuot": 140,
}

type Store struct {
	mu          sync.Mutex
	byToken     map[string]*Player
	players     map[string]*Player
	territories []*Territory
	gangs       map[string]*Gang
	boss        *Boss
	demoSeeded  bool
	demoTokens  map[string]string
	npcRaids    []npcRaid
	npcTick     time.Time
}

func NewStore() *Store {
	return &Store{
		byToken:     map[string]*Player{},
		players:     map[string]*Player{},
		territories: NewTerritories(),
		gangs:       map[string]*Gang{},
		boss:        newBoss(time.Now()),
		npcTick:     time.Now(),
	}
}

type BusinessView struct {
	ID           string  `json:"id"`
	Name         string  `json:"name"`
	Icon         string  `json:"icon"`
	Level        int     `json:"level"`
	Rate         float64 `json:"rate"`
	UpgradeCost  int64   `json:"upgradeCost"`
	Unlocked     bool    `json:"unlocked"`
	UnlockName   string  `json:"unlockName"`
	UnlockAtRank int     `json:"unlockAtRank"`
	Racket       int     `json:"racket"`
	RacketCost   int64   `json:"racketCost"`
}

type CrewSkillView struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Desc   string `json:"desc"`
	Rarity string `json:"rarity"`
}

type GeneralView struct {
	ID        string        `json:"id"`
	Name      string        `json:"name"`
	Level     int           `json:"level"`
	SkillA    CrewSkillView `json:"skillA"`
	SkillB    CrewSkillView `json:"skillB"`
	Power     int           `json:"power"`
	TrainCost int64         `json:"trainCost"`
}

const maxGenerals = 3

var generalNames = []string{
	"Tám Ngón", "Mập Hẻm", "Cò Quay", "Bà Chị Hạnh", "Chú Bảy",
	"Đầu Bạc", "Thằng Câm", "Ông Kẹ", "Cô Ba", "Tư Đen",
}

func skillView(id string) CrewSkillView {
	if def := SkillByID(id); def != nil {
		return CrewSkillView{ID: def.ID, Name: def.Name, Desc: def.Desc, Rarity: def.Rarity}
	}
	return CrewSkillView{}
}

func generalRecruitCost(count int) int64 { return 6000 + 3000*int64(count) }

func generalTrainCost(level int) int64 { return 1200 * int64(level+1) }

func generalViews(p *Player) []GeneralView {
	out := make([]GeneralView, 0, len(p.Generals))
	for _, g := range p.Generals {
		out = append(out, GeneralView{
			ID: g.ID, Name: g.Name, Level: g.Level,
			SkillA: skillView(g.SkillA), SkillB: skillView(g.SkillB),
			Power: 6 + g.Level*3, TrainCost: generalTrainCost(g.Level),
		})
	}
	return out
}

type MissionView struct {
	ID          string `json:"id"`
	Title       string `json:"title"`
	Desc        string `json:"desc"`
	Progress    int    `json:"progress"`
	Target      int    `json:"target"`
	RewardMoney int64  `json:"rewardMoney"`
	RewardUy    int64  `json:"rewardUy"`
	Claimed     bool   `json:"claimed"`
	Claimable   bool   `json:"claimable"`
}

type RankView struct {
	Level int    `json:"level"`
	Name  string `json:"name"`
	Uy    int64  `json:"uy"`
}

type StateView struct {
	Name              string           `json:"name"`
	Money             int64            `json:"money"`
	Uy                int64            `json:"uy"`
	Rank              RankView         `json:"rank"`
	NextRank          *RankView        `json:"nextRank"`
	Rate              float64          `json:"rate"`
	Power             int              `json:"power"`
	Weapon            Weapon           `json:"weapon"`
	NextWeapon        *Weapon          `json:"nextWeapon"`
	RosterCost        int64            `json:"rosterCost"`
	Crew              int              `json:"crew"`
	CrewCost          int64            `json:"crewCost"`
	OwnedCount        int              `json:"ownedCount"`
	TerritoryMul      float64          `json:"territoryMul"`
	Level             int              `json:"level"`
	XP                int64            `json:"xp"`
	XPNext            int64            `json:"xpNext"`
	Points            int              `json:"points"`
	Stats             map[string]int   `json:"stats"`
	GangID            string           `json:"gangId"`
	GangName          string           `json:"gangName"`
	GangMembers       int              `json:"gangMembers"`
	GangBonus         float64          `json:"gangBonus"`
	ShieldUntil       int64            `json:"shieldUntil"`
	MaxOwned          int              `json:"maxOwned"`
	Daily             []MissionView    `json:"daily"`
	DailyResetAt      int64            `json:"dailyResetAt"`
	Unread            int              `json:"unread"`
	Contract          *ContractView    `json:"contract"`
	CasinoLeft        int              `json:"casinoLeft"`
	SeasonKey         string           `json:"seasonKey"`
	SeasonUy          int64            `json:"seasonUy"`
	Items             []string         `json:"items"`
	PlayerID          string           `json:"playerId"`
	Heat              int              `json:"heat"`
	HeatPenalty       float64          `json:"heatPenalty"`
	BribeCost         int64            `json:"bribeCost"`
	Formation         string           `json:"formation"`
	Guards            []GuardSlot      `json:"guards"`
	GuardsTotal       int              `json:"guardsTotal"`
	AvailableCrew     int              `json:"availableCrew"`
	Minions           int              `json:"minions"`
	MinionHealthy     int              `json:"minionHealthy"`
	Wounds            int              `json:"wounds"`
	MinionPower       int              `json:"minionPower"`
	MinionRecruitCost int64            `json:"minionRecruitCost"`
	MinionHealCost    int64            `json:"minionHealCost"`
	MaxMinions        int              `json:"maxMinions"`
	MinionGear        []MinionGearView `json:"minionGear"`
	Upkeep            float64          `json:"upkeep"`
	DistrictHeld      int              `json:"districtHeld"`
	DistrictBonus     float64          `json:"districtBonus"`
	Generals          []GeneralView    `json:"generals"`
	GeneralCost       int64            `json:"generalCost"`
	GeneralPower      int              `json:"generalPower"`
	Bounty            int64            `json:"bounty"`
	LandIncome        float64          `json:"landIncome"`
	Prestige          int              `json:"prestige"`
	PrestigeMul       float64          `json:"prestigeMultiplier"`
	CanPrestige       bool             `json:"canPrestige"`
	Chapter           int              `json:"chapter"`
	Weapons           []Weapon         `json:"weapons"`
	Businesses        []BusinessView   `json:"businesses"`
	Missions          []MissionView    `json:"missions"`
	CrewSkills        []CrewSkillView  `json:"crewSkills"`
}

type RankRow struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Rank   string `json:"rank"`
	Uy     int64  `json:"uy"`
	Power  int    `json:"power"`
	Owned  int    `json:"owned"`
	IsMe   bool   `json:"isMe"`
	Bounty int64  `json:"bounty"`
	Money  int64  `json:"-"`
	Player string `json:"-"`
}

type BrawlEvent struct {
	At      int    `json:"at"`
	Side    string `json:"side"`
	Crit    bool   `json:"crit"`
	Miss    bool   `json:"miss"`
	Dmg     int    `json:"dmg"`
	MyHp    int    `json:"myHp"`
	EnemyHp int    `json:"enemyHp"`
	Text    string `json:"text"`
}

type BrawlResult struct {
	Win           bool         `json:"win"`
	Events        []BrawlEvent `json:"events"`
	Reward        int64        `json:"reward"`
	UyGain        int64        `json:"uyGain"`
	Bounty        int64        `json:"bounty"`
	XP            int64        `json:"xp"`
	Levelups      int          `json:"levelups"`
	LevelupMoney  int64        `json:"levelupMoney"`
	Power         int          `json:"power"`
	Defense       int          `json:"defense"`
	Wounded       int          `json:"wounded"`
	TerritoryID   int          `json:"territoryId"`
	TerritoryName string       `json:"territoryName"`
}

type fighter struct {
	hp         int
	hitDmg     int
	critEvery  int
	dodgeEvery int
	firstHitX2 bool
	dr         float64
}

func jitter(dmg int) int {
	d := dmg * (88 + mrand.Intn(25)) / 100
	if d < 1 {
		return 1
	}
	return d
}

func crits(every int) bool { return every > 0 && mrand.Intn(every) == 0 }

// Mỗi hiệp hai bên ra đòn: sát thương lệch ±12%, chí mạng ngẫu nhiên theo tỉ lệ
// 1/critEvery, nên hai trận cùng chỉ số không còn ra y hệt nhau.
func simulateBrawl(me, foe fighter) ([]BrawlEvent, bool) {
	hpMe, hpEn := me.hp, foe.hp
	events := make([]BrawlEvent, 0, 16)
	at := 0
	add := func(side string, crit, miss bool, dmg int) {
		if side == "me" {
			hpEn -= dmg
		} else {
			hpMe -= dmg
		}
		events = append(events, BrawlEvent{
			At: at, Side: side, Crit: crit, Miss: miss, Dmg: dmg,
			MyHp: max(hpMe, 0), EnemyHp: max(hpEn, 0),
		})
		at += 380
	}
	for round := 1; round <= 40 && hpMe > 0 && hpEn > 0; round++ {
		if foe.dodgeEvery > 0 && round%foe.dodgeEvery == 0 {
			add("me", false, true, 0)
		} else {
			dmg := jitter(me.hitDmg)
			crit := crits(me.critEvery)
			if crit {
				dmg = dmg * 17 / 10
			}
			if round == 1 && me.firstHitX2 {
				dmg *= 2
			}
			if dmg = int(float64(dmg) * (1 - foe.dr)); dmg < 1 {
				dmg = 1
			}
			add("me", crit, false, dmg)
		}
		if hpEn <= 0 {
			break
		}
		if me.dodgeEvery > 0 && round%me.dodgeEvery == 0 {
			add("enemy", false, true, 0)
			continue
		}
		dmg := jitter(foe.hitDmg)
		crit := crits(foe.critEvery)
		if crit {
			dmg = dmg * 17 / 10
		}
		if dmg = int(float64(dmg) * (1 - me.dr)); dmg < 1 {
			dmg = 1
		}
		add("enemy", crit, false, dmg)
	}
	return events, hpEn <= 0 && hpMe > 0
}

func token() string {
	b := make([]byte, 16)
	_, _ = rand.Read(b)
	return hex.EncodeToString(b)
}

func (s *Store) Login(name string) (*Player, string, error) {
	name = strings.TrimSpace(name)
	if utf8.RuneCountInString(name) < 2 {
		return nil, "", errors.New("tên phải từ 2 ký tự")
	}
	if utf8.RuneCountInString(name) > 20 {
		return nil, "", errors.New("tên tối đa 20 ký tự")
	}
	p := &Player{
		ID:           token(),
		Name:         name,
		Money:        500,
		Uy:           0,
		Level:        1,
		Stats:        map[string]int{},
		WeaponIdx:    0,
		Levels:       map[string]int{"karaoke": 1, "matxa": 1, "baixe": 1},
		Owned:        map[int]bool{},
		Missions:     map[string]int{},
		Claimed:      map[string]bool{},
		DailyDay:     time.Now().In(ictZone).Format("2006-01-02"),
		Daily:        map[string]int{},
		DailyClaimed: map[string]bool{},
		Items:        map[string]bool{},
		Guards:       map[int]int{},
		Gear:         map[string]int{},
		Racket:       map[string]int{},
		Formation:    "balanced",
		HeatAt:       time.Now(),
		SeasonKey:    time.Now().In(ictZone).Format("2006-01"),
		LastAccrual:  time.Now(),
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.players[p.ID] = p
	t := token()
	s.byToken[t] = p
	return p, t, nil
}

func (s *Store) player(tok string) (*Player, error) {
	p, ok := s.byToken[tok]
	if !ok {
		return nil, errors.New("phiên đăng nhập hết hạn")
	}
	return p, nil
}

var ictZone = time.FixedZone("ICT", 7*3600)

func (p *Player) rollDaily(now time.Time) {
	day := now.In(ictZone).Format("2006-01-02")
	if p.DailyDay == day {
		return
	}
	p.DailyDay = day
	p.Daily = map[string]int{}
	p.DailyClaimed = map[string]bool{}
}

func DailyResetAt(now time.Time) int64 {
	local := now.In(ictZone)
	midnight := time.Date(local.Year(), local.Month(), local.Day(), 0, 0, 0, 0, ictZone).Add(24 * time.Hour)
	return midnight.Unix()
}

type dailyDef struct {
	ID   string
	Kind string
}

var dailyDefs = []dailyDef{
	{"d_win", "win"},
	{"d_earn", "earn"},
	{"d_upgrade", "upgrade"},
}

func dailyTarget(level int, id string) int {
	switch id {
	case "d_win":
		return 2 + level/10
	case "d_earn":
		return 2000 + level*600
	default:
		return 2 + level/8
	}
}

func dailyReward(level int) (money, uy int64) {
	return 400 + int64(level)*150, 15 + int64(level)*2
}

func dailyViews(p *Player) []MissionView {
	out := make([]MissionView, 0, len(dailyDefs))
	money, uy := dailyReward(p.Level)
	titles := map[string][2]string{
		"d_win":     {"Dằn mặt", "Thắng %d trận chiếm địa bàn"},
		"d_earn":    {"Tiền về", "Kiếm %s từ cơ sở"},
		"d_upgrade": {"Làm ăn", "Nâng cấp cơ sở %d lần"},
	}
	for _, def := range dailyDefs {
		target := dailyTarget(p.Level, def.ID)
		progress := p.Daily[def.Kind]
		info := titles[def.ID]
		desc := info[1]
		if def.ID == "d_earn" {
			desc = fmt.Sprintf(info[1], formatVND(int64(target)))
		} else {
			desc = fmt.Sprintf(info[1], target)
		}
		out = append(out, MissionView{
			ID: def.ID, Title: info[0], Desc: desc,
			Progress: progress, Target: target,
			RewardMoney: money, RewardUy: uy,
			Claimed:   p.DailyClaimed[def.ID],
			Claimable: !p.DailyClaimed[def.ID] && progress >= target,
		})
	}
	return out
}

func formatVND(v int64) string {
	switch {
	case v >= 1000000:
		return fmt.Sprintf("%.1fTr", float64(v)/1000000)
	case v >= 1000:
		return fmt.Sprintf("%.1fk", float64(v)/1000)
	default:
		return fmt.Sprintf("%d", v)
	}
}

func newBoss(now time.Time) *Boss {
	year, week := now.In(ictZone).ISOWeek()
	return &Boss{
		Week:   fmt.Sprintf("%d-W%02d", year, week),
		HP:     120000,
		MaxHP:  120000,
		Damage: map[string]int64{},
	}
}

func rollSeason(p *Player, now time.Time) {
	key := now.In(ictZone).Format("2006-01")
	if p.SeasonKey != key {
		p.SeasonKey = key
		p.SeasonUy = 0
	}
}

func (p *Player) addUy(n int64) {
	p.Uy += n
	if p.Uy < 0 {
		p.Uy = 0
	}
	if n > 0 {
		p.SeasonUy += n
	}
}

func (p *Player) addInbox(msg InboxMsg) {
	p.Inbox = append([]InboxMsg{msg}, p.Inbox...)
	if len(p.Inbox) > 30 {
		p.Inbox = p.Inbox[:30]
	}
}

func unreadCount(p *Player) int {
	n := 0
	for _, m := range p.Inbox {
		if !m.Read {
			n++
		}
	}
	return n
}

func warWindowOpen(now time.Time) bool {
	h := now.In(ictZone).Hour()
	return h >= 20 && h < 22
}

func (p *Player) contractProgress(c *Contract) int {
	if c == nil {
		return 0
	}
	switch c.Kind {
	case "win":
		return int(int64(p.Missions["win"]) - c.Starts)
	case "earn":
		return int(p.Earned - c.Starts)
	}
	return 0
}

func contractOffers(p *Player) []ContractView {
	lvl := int64(p.Level)
	return []ContractView{
		{
			ID: "c_win", Title: "Dằn mặt", Kind: "win",
			Desc:    fmt.Sprintf("Thắng %d trận trong 15 phút", 2+int(lvl)/12),
			Target:  2 + int(lvl)/12,
			Deposit: 200 + lvl*80, RewardMoney: 1200 + lvl*350, RewardUy: 30 + lvl*3,
		},
		{
			ID: "c_bigwin", Title: "Làm lớn", Kind: "win",
			Desc:    fmt.Sprintf("Thắng %d trận trong 20 phút", 4+int(lvl)/8),
			Target:  4 + int(lvl)/8,
			Deposit: 500 + lvl*150, RewardMoney: 3000 + lvl*800, RewardUy: 80 + lvl*6,
		},
		{
			ID: "c_earn", Title: "Chạy doanh thu", Kind: "earn",
			Desc:    fmt.Sprintf("Kiếm %s trong 15 phút", formatVND(3000+lvl*1200)),
			Target:  3000 + int(lvl)*1200,
			Deposit: 400 + lvl*120, RewardMoney: 2000 + lvl*600, RewardUy: 60 + lvl*4,
		},
	}
}

func contractView(c *Contract, progress int, now time.Time) ContractView {
	remaining := int64(0)
	if c != nil && c.EndsAt.After(now) {
		remaining = int64(c.EndsAt.Sub(now).Seconds())
	}
	return ContractView{
		ID: c.ID, Title: c.Title, Desc: c.Desc, Target: c.Target,
		Progress: progress, Deposit: c.Deposit,
		RewardMoney: c.RewardMoney, RewardUy: c.RewardUy,
		Remaining: remaining, Active: true,
		Complete: progress >= c.Target,
	}
}

func (s *Store) settleWarsLocked(now time.Time) {
	if now.In(ictZone).Hour() < 22 {
		return
	}
	day := now.In(ictZone).Format("2006-01-02")
	scored := make([]*Gang, 0)
	for _, g := range s.gangs {
		if g.WarDay == day && g.WarSettledDay != day {
			g.WarSettledDay = day
			if g.WarScore > 0 {
				scored = append(scored, g)
			}
		}
	}
	if len(scored) == 0 {
		return
	}
	sort.Slice(scored, func(i, j int) bool { return scored[i].WarScore > scored[j].WarScore })
	type reward struct {
		treasury, money, uy int64
	}
	rewards := []reward{{5000, 1000, 50}, {3000, 600, 30}, {1500, 300, 15}}
	for i, g := range scored {
		if i >= len(rewards) {
			break
		}
		r := rewards[i]
		g.Treasury += r.treasury
		for _, id := range g.Members {
			m := s.players[id]
			if m == nil {
				continue
			}
			m.Money += r.money
			m.addUy(r.uy)
			m.addInbox(InboxMsg{
				ID: token(), Kind: "war", At: now.Unix(),
				Text: fmt.Sprintf("Chiến băng hôm nay: băng %s hạng %d — +%dđ, +%d uy, quỹ băng +%d",
					g.Name, i+1, r.money, r.uy, r.treasury),
			})
		}
	}
}

func (s *Store) rollGangsLocked(now time.Time) {
	s.settleWarsLocked(now)
	day := now.In(ictZone).Format("2006-01-02")
	for _, g := range s.gangs {
		if g.WarDay != day {
			g.WarDay = day
			g.WarScore = 0
		}
	}
}

func (s *Store) rollContractLocked(p *Player, now time.Time) {
	c := p.Contract
	if c == nil {
		return
	}
	if now.After(c.EndsAt) && p.contractProgress(c) < c.Target {
		p.Contract = nil
		p.addInbox(InboxMsg{
			ID: token(), Kind: "contract", At: now.Unix(),
			Text: fmt.Sprintf("Hợp đồng %s thất bại, mất cọc", c.Title),
		})
	}
}

func (s *Store) accrue(p *Player, now time.Time) {
	elapsed := now.Sub(p.LastAccrual)
	if elapsed <= 0 {
		return
	}
	if elapsed > offlineCap {
		elapsed = offlineCap
	}
	p.rollDaily(now)
	rollSeason(p, now)
	s.rollContractLocked(p, now)
	s.tickNPCsLocked(now)
	if p.HeatAt.IsZero() {
		p.HeatAt = now
	}
	if p.Heat > 0 && now.Sub(p.HeatAt) >= 3*time.Minute {
		steps := int(now.Sub(p.HeatAt) / (3 * time.Minute))
		p.Heat -= steps
		if p.Heat < 0 {
			p.Heat = 0
		}
		p.HeatAt = p.HeatAt.Add(time.Duration(steps) * 3 * time.Minute)
	}
	if p.Wounds > 0 {
		if p.WoundAt.IsZero() {
			p.WoundAt = now
		}
		if steps := int(now.Sub(p.WoundAt) / time.Minute); steps > 0 {
			p.Wounds -= steps
			if p.Wounds < 0 {
				p.Wounds = 0
			}
			p.WoundAt = p.WoundAt.Add(time.Duration(steps) * time.Minute)
			if p.Wounds == 0 {
				p.WoundAt = time.Time{}
			}
		}
	}
	gain := int64(p.RatePerSec() * elapsed.Seconds())
	p.Earned += gain
	p.Daily["earn"] += int(gain)
	tithe := int64(0)
	if g := s.gangs[p.GangID]; g != nil && g.TributeTo != "" {
		if protector := s.gangs[g.TributeTo]; protector != nil {
			tithe = gain / 10
			protector.Treasury += tithe
		}
	}
	p.Money += gain - tithe
	if upkeep := int64(p.UpkeepPerSec() * elapsed.Seconds()); upkeep > 0 {
		p.Money -= upkeep
		if p.Money < 0 {
			p.Money = 0
			s.desertLocked(p, now)
		}
	}
	p.LastAccrual = now
}

// desertLocked: hết tiền trả lương thì lính/đàn em bỏ đi.
func (s *Store) desertLocked(p *Player, now time.Time) {
	if now.Sub(p.UpkeepMsgAt) < 30*time.Second {
		return
	}
	p.UpkeepMsgAt = now
	if p.Minions > 0 {
		lost := p.Minions / 10
		if lost < 1 {
			lost = 1
		}
		p.Minions -= lost
		if p.Wounds > p.Minions {
			p.Wounds = p.Minions
		}
		p.addInbox(InboxMsg{
			ID: token(), Kind: "upkeep", At: now.Unix(),
			Text: fmt.Sprintf("Hết tiền trả lương, %d lính bỏ đi", lost),
		})
		return
	}
	if p.Crew > 0 {
		p.Crew--
		p.addInbox(InboxMsg{
			ID: token(), Kind: "upkeep", At: now.Unix(),
			Text: "Hết tiền trả lương, 1 đàn em bỏ đi",
		})
	}
}

func XPNeed(level int) int64 {
	return int64(100*level + 25*level*level)
}

func (p *Player) AddXP(n int64) (levelups int, moneyReward int64) {
	if p.Level >= 50 {
		return 0, 0
	}
	p.XP += n
	for p.Level < 50 && p.XP >= XPNeed(p.Level) {
		p.XP -= XPNeed(p.Level)
		p.Level++
		p.Points++
		reward := int64(200 * p.Level)
		p.Money += reward
		moneyReward += reward
		levelups++
	}
	if p.Level >= 50 {
		p.XP = 0
	}
	return levelups, moneyReward
}

func (p *Player) GuardsTotal() int {
	total := 0
	for _, n := range p.Guards {
		total += n
	}
	return total
}

func (p *Player) AvailableCrew() int {
	n := p.Crew - p.GuardsTotal()
	if n < 0 {
		return 0
	}
	return n
}

func (p *Player) HeatPenalty() float64 {
	r := float64(p.Heat) / 200
	if r > 0.5 {
		return 0.5
	}
	return r
}

func (p *Player) BribeCost() int64 {
	if p.Heat <= 0 {
		return 0
	}
	return int64(p.Heat) * 80
}

func (p *Player) PrestigeMultiplier() float64 {
	return 1 + 0.1*float64(p.Prestige)
}

func (p *Player) BonusHP() int { return p.Stats["hp"] * 25 }

func (p *Player) BonusDmg() int { return p.Stats["dmg"] * 3 }

func (p *Player) DamageReduction() float64 {
	r := 0.02 * float64(p.Stats["armor"])
	if r > 0.5 {
		return 0.5
	}
	return r
}

func businessView(p *Player, def BusinessDef) BusinessView {
	rank := RankFor(p.Uy)
	unlocked := rank.Level >= def.Unlock
	lvl := p.Levels[def.ID]
	return BusinessView{
		ID:           def.ID,
		Name:         def.Name,
		Icon:         def.Icon,
		Level:        lvl,
		Rate:         p.BusinessRate(def),
		UpgradeCost:  UpgradeCost(def, lvl),
		Unlocked:     unlocked,
		UnlockName:   Ranks[def.Unlock].Name,
		UnlockAtRank: def.Unlock,
		Racket:       p.Racket[def.ID],
		RacketCost:   racketCost(p.Racket[def.ID]),
	}
}

func racketCost(level int) int64 {
	if level >= 3 {
		return 0
	}
	return 400 * int64(level+1) * int64(level+1)
}

func (s *Store) stateLocked(p *Player) StateView {
	rank := RankFor(p.Uy)
	var next *RankView
	if n := NextRank(p.Uy); n != nil {
		next = &RankView{Level: n.Level, Name: n.Name, Uy: n.Uy}
	}
	var nw *Weapon
	if p.WeaponIdx+1 < len(Weapons) {
		w := Weapons[p.WeaponIdx+1]
		nw = &w
	}
	biz := make([]BusinessView, 0, len(BusinessDefs))
	for _, def := range BusinessDefs {
		biz = append(biz, businessView(p, def))
	}
	return StateView{
		Name:              p.Name,
		Money:             p.Money,
		Uy:                p.Uy,
		Rank:              RankView{Level: rank.Level, Name: rank.Name, Uy: rank.Uy},
		NextRank:          next,
		Rate:              p.RatePerSec(),
		Power:             p.Power(),
		Weapon:            p.Weapon(),
		NextWeapon:        nw,
		RosterCost:        p.RosterUpgradeCost(),
		Crew:              p.Crew,
		CrewCost:          RecruitCost(p.Crew),
		OwnedCount:        p.OwnedCount(),
		TerritoryMul:      p.TerritoryMultiplier(),
		Level:             p.Level,
		XP:                p.XP,
		XPNext:            XPNeed(p.Level),
		Points:            p.Points,
		Stats:             p.Stats,
		GangID:            p.GangID,
		GangName:          s.gangNameLocked(p.GangID),
		GangMembers:       s.gangMembersLocked(p.GangID),
		GangBonus:         s.gangBonusLocked(p),
		ShieldUntil:       p.ShieldUntil.Unix(),
		MaxOwned:          MaxTerritories(RankFor(p.Uy).Level),
		Daily:             dailyViews(p),
		DailyResetAt:      DailyResetAt(time.Now()),
		Unread:            unreadCount(p),
		Contract:          contractStateView(p, time.Now()),
		CasinoLeft:        max(0, 5-p.Daily["casino"]),
		SeasonKey:         p.SeasonKey,
		SeasonUy:          p.SeasonUy,
		Items:             ownedItems(p),
		PlayerID:          p.ID,
		Heat:              p.Heat,
		HeatPenalty:       p.HeatPenalty(),
		BribeCost:         p.BribeCost(),
		Formation:         p.Formation,
		Guards:            s.guardSlotsLocked(p),
		GuardsTotal:       p.GuardsTotal(),
		AvailableCrew:     p.AvailableCrew(),
		Minions:           p.Minions,
		MinionHealthy:     p.MinionHealthy(),
		Wounds:            p.Wounds,
		MinionPower:       p.MinionPower(),
		MinionRecruitCost: p.MinionRecruitCost(1),
		MinionHealCost:    minionHealCost,
		MaxMinions:        MaxMinions,
		MinionGear:        minionGearViews(p),
		Upkeep:            p.UpkeepPerSec(),
		DistrictHeld:      p.DistrictHeld,
		DistrictBonus:     p.DistrictBonus,
		Generals:          generalViews(p),
		GeneralCost:       generalRecruitCost(len(p.Generals)),
		GeneralPower:      p.GeneralPower(),
		Bounty:            p.Bounty,
		LandIncome:        p.LandIncome,
		Prestige:          p.Prestige,
		PrestigeMul:       p.PrestigeMultiplier(),
		CanPrestige:       p.Uy >= 15000,
		Chapter:           p.Chapter,
		Weapons:           append([]Weapon(nil), Weapons...),
		Businesses:        biz,
		Missions:          missionViews(p),
		CrewSkills:        crewSkillViews(p),
	}
}

func (s *Store) State(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	return s.stateLocked(p), nil
}

func (s *Store) UpgradeBusiness(tok, id string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	var def *BusinessDef
	for i := range BusinessDefs {
		if BusinessDefs[i].ID == id {
			def = &BusinessDefs[i]
		}
	}
	if def == nil {
		return StateView{}, errors.New("cơ sở không tồn tại")
	}
	if RankFor(p.Uy).Level < def.Unlock {
		return StateView{}, fmt.Errorf("cần đạt %s để mở", Ranks[def.Unlock].Name)
	}
	lvl := p.Levels[id]
	cost := UpgradeCost(*def, lvl)
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền")
	}
	p.Money -= cost
	p.Levels[id] = lvl + 1
	p.Missions["upgrade"]++
	p.Daily["upgrade"]++
	p.AddXP(15)
	return s.stateLocked(p), nil
}

func (s *Store) Recruit(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	cost := RecruitCost(p.Crew)
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền nuôi quân")
	}
	p.Money -= cost
	p.Crew++
	p.CrewSkills = append(p.CrewSkills, rollSkill())
	p.Missions["recruit"]++
	p.AddXP(20)
	return s.stateLocked(p), nil
}

func (p *Player) applyWounds(n int) int {
	if n <= 0 {
		return 0
	}
	if max := p.MinionHealthy(); n > max {
		n = max
	}
	if n <= 0 {
		return 0
	}
	p.Wounds += n
	p.WoundAt = time.Now()
	return n
}

func (p *Player) healWounds(n int) int {
	if n > p.Wounds {
		n = p.Wounds
	}
	if n <= 0 {
		return 0
	}
	p.Wounds -= n
	if p.Wounds == 0 {
		p.WoundAt = time.Time{}
	}
	return n
}

func (s *Store) RecruitMinions(tok string, count int) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if count < 1 {
		return StateView{}, errors.New("mộ bao nhiêu lính?")
	}
	if count > 100 {
		count = 100
	}
	if p.Minions+count > MaxMinions {
		return StateView{}, fmt.Errorf("băng chỉ nuôi tối đa %d lính", MaxMinions)
	}
	cost := p.MinionRecruitCost(count)
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền mộ lính")
	}
	p.Money -= cost
	p.Minions += count
	p.Missions["recruit"]++
	return s.stateLocked(p), nil
}

func (s *Store) BuyMinionGear(tok, id string, count int) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	def := MinionGearByID(id)
	if def == nil {
		return StateView{}, errors.New("món đồ này không có cho lính")
	}
	if count < 1 {
		return StateView{}, errors.New("mua bao nhiêu món?")
	}
	if p.Gear == nil {
		p.Gear = map[string]int{}
	}
	owned := 0
	for _, n := range p.Gear {
		owned += n
	}
	if owned+count > p.Minions {
		return StateView{}, errors.New("mày đâu có đủ lính để cầm chỗ vũ khí đó")
	}
	cost := def.Cost * int64(count)
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền mua đồ cho lính")
	}
	p.Money -= cost
	p.Gear[id] += count
	return s.stateLocked(p), nil
}

func (s *Store) HealMinions(tok string, count int) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if p.Wounds <= 0 {
		return StateView{}, errors.New("không có lính nào bị thương")
	}
	if count < 1 || count > p.Wounds {
		count = p.Wounds
	}
	cost := p.MinionHealCost(count)
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền mua băng bó")
	}
	p.Money -= cost
	p.healWounds(count)
	return s.stateLocked(p), nil
}

func (s *Store) UpgradeWeapon(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if p.WeaponIdx+1 >= len(Weapons) {
		return StateView{}, errors.New("đã là hàng nóng xịn nhất")
	}
	cost := Weapons[p.WeaponIdx+1].Cost
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền mua hàng nóng")
	}
	p.Money -= cost
	p.WeaponIdx++
	p.Missions["weapon"]++
	p.AddXP(30)
	return s.stateLocked(p), nil
}

func (s *Store) Map(tok string) ([]Territory, StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return nil, StateView{}, err
	}
	s.accrue(p, time.Now())
	out := make([]Territory, len(s.territories))
	for i, t := range s.territories {
		out[i] = *t
		if strings.HasPrefix(t.OwnerID, "p:") {
			if owner, ok := s.players[strings.TrimPrefix(t.OwnerID, "p:")]; ok {
				out[i].OwnerGangID = owner.GangID
			}
		}
	}
	return out, s.stateLocked(p), nil
}

func (s *Store) defenseOf(t *Territory) int {
	def := t.Defense
	if strings.HasPrefix(t.OwnerID, "p:") {
		if owner, ok := s.players[strings.TrimPrefix(t.OwnerID, "p:")]; ok {
			if p := owner.Power(); p > def {
				def = p
			}
			def += owner.Guards[t.ID]*10 + t.Level*8
			if owner.DistrictCount[DistrictOf(t.ID)] >= DistrictSize {
				def += 12
			}
		}
	}
	return def
}

func (s *Store) Attack(tok string, id int) (BrawlResult, StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return BrawlResult{}, StateView{}, err
	}
	s.accrue(p, time.Now())
	if id < 0 || id >= len(s.territories) {
		return BrawlResult{}, StateView{}, errors.New("địa bàn không tồn tại")
	}
	t := s.territories[id]
	if t.OwnerID == "p:"+p.ID {
		return BrawlResult{}, StateView{}, errors.New("địa bàn này đã là của mày")
	}
	if !p.DevUnlimited && time.Since(p.LastBrawl) < 2*time.Second {
		return BrawlResult{}, StateView{}, errors.New("từ từ, thở đã")
	}
	if !p.DevUnlimited && p.Heat >= 80 {
		return BrawlResult{}, StateView{}, errors.New("cớm đang để ý, đút lót trước rồi hẵng chém")
	}

	maxOwned := MaxTerritories(RankFor(p.Uy).Level)
	if !p.DevUnlimited && p.OwnedCount() >= maxOwned {
		return BrawlResult{}, StateView{}, fmt.Errorf("cấp %s chỉ giữ được %d địa bàn, lên bậc rồi tính", RankFor(p.Uy).Name, maxOwned)
	}
	var defender *Player
	if strings.HasPrefix(t.OwnerID, "p:") {
		defender = s.players[strings.TrimPrefix(t.OwnerID, "p:")]
		if defender != nil && p.GangID != "" && defender.GangID == p.GangID {
			return BrawlResult{}, StateView{}, errors.New("đồng minh trong băng, không chém nhau")
		}
		if defender != nil && p.GangID != "" && defender.GangID != "" {
			now := time.Now()
			mine := s.gangs[p.GangID]
			theirs := s.gangs[defender.GangID]
			if mine != nil && theirs != nil {
				if mine.allied(now, theirs.ID) {
					return BrawlResult{}, StateView{}, errors.New("băng đang liên minh, không chém nhau")
				}
				if theirs.TributeTo == mine.ID {
					return BrawlResult{}, StateView{}, errors.New("băng này đang nộp cống cho mày, đánh nó là mất nguồn")
				}
			}
		}
		atWar := s.atWarLocked(p, defender)
		if defender != nil && !atWar {
			if !p.DevUnlimited && defender.ShieldUntil.After(time.Now()) {
				return BrawlResult{}, StateView{}, errors.New("chủ địa bàn đang có khiên, để mai tính")
			}
			if defender.Uy < 300 && p.Uy >= 2000 {
				return BrawlResult{}, StateView{}, errors.New("đừng bắt nạt tân binh")
			}
		}
	}
	revenge := defender != nil && p.RevengeUntil.After(time.Now()) && p.RevengeTarget == defender.ID
	defense := s.defenseOf(t)
	tierGap := 0
	if defender != nil && p.GangID != "" && defender.GangID != "" && defender.GangID != p.GangID {
		atkTier := s.gangTierLocked(s.gangs[p.GangID])
		defTier := s.gangTierLocked(s.gangs[defender.GangID])
		if atkTier > 0 && defTier > atkTier {
			tierGap = defTier - atkTier
			if tierGap > 2 {
				tierGap = 2
			}
		}
	}
	if tierGap > 0 {
		defense = defense * (100 + 10*tierGap) / 100
	}
	power := p.Power() - p.GuardsTotal()*6
	if power < 10 {
		power = 10
	}
	power = int(float64(power) * s.gangBonusLocked(p))
	if g := s.gangs[p.GangID]; g != nil && g.BoostUntil.After(time.Now()) {
		power = power * 11 / 10
	}
	eff := p.AllEffects()
	hpMe := 150 + p.AvailableCrew()*20 + eff.HpAdd + p.BonusHP() +
		p.MinionHealthy()/4 + p.GeneralHP()
	myHitDmg := int(float64(power/2+4) * (1 + eff.DmgMul))
	critEvery := eff.CritEvery
	if critEvery == 0 {
		critEvery = 3
	}
	if p.Formation == "sneak" {
		critEvery--
		if critEvery < 1 {
			critEvery = 1
		}
	}
	if p.Formation == "front" {
		myHitDmg = myHitDmg * 115 / 100
		hpMe = hpMe * 9 / 10
	}
	if p.Formation == "sneak" {
		myHitDmg = myHitDmg * 9 / 10
	}

	foe := fighter{hp: 120 + defense, hitDmg: defense/5 + 3, critEvery: 4}
	if defender != nil {
		foeEff := defender.SkillEffects()
		foe.hp += foeEff.HpAdd
		foe.hitDmg = int(float64(foe.hitDmg) * (1 + foeEff.DmgMul))
		foe.dodgeEvery = foeEff.DodgeEvery
		foe.dr = defender.DamageReduction()
		if foeEff.CritEvery > 0 {
			foe.critEvery = foeEff.CritEvery
		}
	}

	res := BrawlResult{
		Power: power, Defense: defense,
		TerritoryID: id, TerritoryName: t.Name,
	}
	res.Events, res.Win = simulateBrawl(fighter{
		hp: hpMe, hitDmg: myHitDmg, critEvery: critEvery,
		dodgeEvery: eff.DodgeEvery, firstHitX2: eff.FirstHitX2, dr: p.DamageReduction(),
	}, foe)
	p.LastBrawl = time.Now()
	if healthy := p.MinionHealthy(); healthy > 0 {
		rate := 10
		if !res.Win {
			rate = 16
		}
		w := healthy * rate / 100
		if w < 1 {
			w = 1
		}
		res.Wounded = p.applyWounds(w)
	}

	atWar := defender != nil && s.atWarLocked(p, defender)
	if res.Win {
		res.Reward = t.Tax * 12
		res.UyGain = t.Tax/2 + 15 + eff.UyBonus
		if atWar {
			res.Reward = res.Reward * 5 / 4
			res.UyGain += t.Tax/2 + 10
		}
		if p.Items["watch"] {
			res.Reward = res.Reward * 11 / 10
		}
		if p.Items["chain"] {
			res.UyGain = res.UyGain * 105 / 100
		}
		if revenge {
			res.Reward = res.Reward * 5 / 4
			res.UyGain += 20
		}
		if tierGap > 0 {
			res.Reward = res.Reward * int64(100-15*tierGap) / 100
			res.UyGain = res.UyGain * int64(100-15*tierGap) / 100
		}
		p.Money += res.Reward
		p.addUy(res.UyGain)
		prevOwner := t.OwnerID
		t.OwnerID = "p:" + p.ID
		t.OwnerName = p.Name
		p.Owned[id] = true
		s.recalcLandLocked(p)
		// Băng NPC nhớ mặt, 30–60 phút nữa kéo quân đòi lại.
		if _, npc := npcGangs[prevOwner]; npc && len(s.npcRaids) < 12 {
			s.npcRaids = append(s.npcRaids, npcRaid{
				GangID: prevOwner, TargetID: "p:" + p.ID, TerritoryID: id,
				At: time.Now().Add(time.Duration(30+mrand.Intn(31)) * time.Minute),
			})
		}
		if defender != nil {
			delete(defender.Owned, id)
			s.recalcLandLocked(defender)
			if dh := defender.MinionHealthy(); dh > 0 {
				w := dh / 12
				if w < 1 {
					w = 1
				}
				defender.applyWounds(w)
			}
		}
		p.Missions["win"]++
		p.Daily["win"]++
		if defender != nil && defender.Bounty > 0 {
			res.Bounty = defender.Bounty
			p.Money += defender.Bounty
			defender.Bounty = 0
			defender.addInbox(InboxMsg{
				ID: token(), Kind: "bounty", At: time.Now().Unix(),
				Text: fmt.Sprintf("%s đã săn được đầu mày", p.Name),
			})
		}
		xpGain := int64(40 + t.Tax/4)
		res.XP = xpGain
		res.Levelups, res.LevelupMoney = p.AddXP(xpGain)
		p.Heat += 8
		if p.Heat > 100 {
			p.Heat = 100
		}
		p.HeatAt = time.Now()
		if defender != nil {
			now := time.Now()
			defender.ShieldUntil = now.Add(lossShield)
			defender.RevengeTarget = p.ID
			defender.RevengeUntil = now.Add(lossShield)
			recordID := token()
			rec := DefenseRecord{
				ID: recordID, At: now.Unix(), AttackerName: p.Name,
				TerritoryID: t.ID, TerritoryName: t.Name,
				Result: flipBrawlForDefender(res, defender),
			}
			defender.Defenses = append([]DefenseRecord{rec}, defender.Defenses...)
			if len(defender.Defenses) > 5 {
				defender.Defenses = defender.Defenses[:5]
			}
			defender.addInbox(InboxMsg{
				ID: token(), Kind: "attack", At: now.Unix(),
				Text:     fmt.Sprintf("%s chém mất %s của mày", p.Name, t.Name),
				FromName: p.Name, TerritoryID: t.ID, BattleID: recordID,
				RevengeUntil: now.Add(lossShield).Unix(),
			})
		}
		s.rollGangsLocked(time.Now())
		if p.GangID != "" && defender != nil && defender.GangID != "" &&
			defender.GangID != p.GangID && warWindowOpen(time.Now()) {
			if g := s.gangs[p.GangID]; g != nil {
				g.WarScore += 2
			}
		}
	} else {
		res.UyGain = -(t.Tax / 4)
		p.addUy(res.UyGain)
		p.Heat += 3
		if p.Heat > 100 {
			p.Heat = 100
		}
		p.HeatAt = time.Now()
		// Thua trận thì tướng có thể bỏ xác.
		if len(p.Generals) > 0 && mrand.Intn(4) == 0 {
			i := mrand.Intn(len(p.Generals))
			dead := p.Generals[i]
			p.Generals = append(p.Generals[:i], p.Generals[i+1:]...)
			p.addInbox(InboxMsg{
				ID: token(), Kind: "general", At: time.Now().Unix(),
				Text: fmt.Sprintf("%s bỏ xác ngoài hẻm, mất một tướng", dead.Name),
			})
		}
	}
	return res, s.stateLocked(p), nil
}

func (s *Store) ClaimDaily(tok, id string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	found := false
	var target int
	for _, def := range dailyDefs {
		if def.ID == id {
			found = true
			target = dailyTarget(p.Level, id)
		}
	}
	if !found {
		return StateView{}, errors.New("nhiệm vụ ngày không tồn tại")
	}
	if p.DailyClaimed[id] {
		return StateView{}, errors.New("hôm nay nhận rồi")
	}
	kind := ""
	for _, def := range dailyDefs {
		if def.ID == id {
			kind = def.Kind
		}
	}
	if p.Daily[kind] < target {
		return StateView{}, errors.New("chưa xong nhiệm vụ ngày")
	}
	p.DailyClaimed[id] = true
	money, uy := dailyReward(p.Level)
	p.Money += money
	p.addUy(uy)
	p.AddXP(30)
	return s.stateLocked(p), nil
}

func (s *Store) SpendPoint(tok, stat string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if p.Points <= 0 {
		return StateView{}, errors.New("không còn điểm tiềm năng")
	}
	switch stat {
	case "hp", "dmg":
	case "armor":
		if p.Stats["armor"] >= 25 {
			return StateView{}, errors.New("giáp đã tối đa (50%)")
		}
	default:
		return StateView{}, errors.New("chỉ số không hợp lệ")
	}
	p.Points--
	p.Stats[stat]++
	return s.stateLocked(p), nil
}

func (s *Store) gangNameLocked(id string) string {
	if g := s.gangs[id]; g != nil {
		return g.Name
	}
	return ""
}

func (s *Store) gangMembersLocked(id string) int {
	if g := s.gangs[id]; g != nil {
		return len(g.Members)
	}
	return 0
}

func (s *Store) gangBonusLocked(p *Player) float64 {
	g := s.gangs[p.GangID]
	if g == nil {
		return 1
	}
	b := 1 + 0.02*float64(len(g.Members)) + 0.01*float64(g.Level)
	if b > 1.35 {
		return 1.35
	}
	return b
}

func (s *Store) atWarLocked(a, b *Player) bool {
	if a == nil || b == nil || a.GangID == "" || b.GangID == "" || a.GangID == b.GangID {
		return false
	}
	ga := s.gangs[a.GangID]
	gb := s.gangs[b.GangID]
	if ga == nil || gb == nil {
		return false
	}
	now := time.Now()
	return ga.atWar(now, gb.ID) || gb.atWar(now, ga.ID)
}

type RelationEdge struct {
	From  string `json:"from"`
	To    string `json:"to"`
	Kind  string `json:"kind"`
	Until int64  `json:"until"`
}

type GangView struct {
	ID                  string `json:"id"`
	Name                string `json:"name"`
	Members             int    `json:"members"`
	MaxMembers          int    `json:"maxMembers"`
	Power               int    `json:"power"`
	Owned               int    `json:"owned"`
	Leader              string `json:"leader"`
	IsMine              bool   `json:"isMine"`
	WarName             string `json:"warName"`
	WarUntil            int64  `json:"warUntil"`
	WarScore            int    `json:"warScore"`
	WarOpen             bool   `json:"warOpen"`
	Tier                int    `json:"tier"`
	Relation            string `json:"relation"`
	Wars                int    `json:"wars"`
	Allies              int    `json:"allies"`
	Treasury            int64  `json:"treasury"`
	TributeToName       string `json:"tributeToName"`
	Tributes            int    `json:"tributes"`
	Level               int    `json:"level"`
	BoostUntil          int64  `json:"boostUntil"`
	ShieldCooldownUntil int64  `json:"shieldCooldownUntil"`
	WarCooldownUntil    int64  `json:"warCooldownUntil"`
	UpgradeCost         int64  `json:"upgradeCost"`
	WarSettled          bool   `json:"warSettled"`
}

func (s *Store) gangViewLocked(g *Gang, me *Player) GangView {
	power := 0
	owned := 0
	leaderName := ""
	for _, id := range g.Members {
		m := s.players[id]
		if m == nil {
			continue
		}
		if id == g.LeaderID {
			leaderName = m.Name
		}
		power += m.Power()
		owned += m.OwnedCount()
	}
	now := time.Now()
	g.pruneRelations(now)
	warName := ""
	var warUntil time.Time
	for id, until := range g.Wars {
		if war := s.gangs[id]; war != nil && until.After(warUntil) {
			warUntil = until
			warName = war.Name
		}
	}
	relation := "neutral"
	if me != nil && me.GangID == g.ID {
		relation = "self"
	} else if mine := s.gangs[meGangID(me)]; mine != nil {
		switch {
		case mine.atWar(now, g.ID):
			relation = "war"
		case mine.allied(now, g.ID):
			relation = "ally"
		case mine.TributeTo == g.ID:
			relation = "protector"
		case g.TributeTo == mine.ID:
			relation = "tributary"
		}
	}
	tributeToName := ""
	if t := s.gangs[g.TributeTo]; t != nil {
		tributeToName = t.Name
	}
	tributes := 0
	for _, other := range s.gangs {
		if other.TributeTo == g.ID {
			tributes++
		}
	}
	return GangView{
		ID: g.ID, Name: g.Name, Members: len(g.Members),
		MaxMembers: gangMaxMembers, Power: power, Owned: owned,
		Leader: leaderName, IsMine: me != nil && me.GangID == g.ID,
		WarName: warName, WarUntil: warUntil.Unix(),
		WarScore: g.WarScore, WarOpen: warWindowOpen(now),
		Relation: relation, Wars: len(g.Wars), Allies: len(g.Allies),
		Treasury: g.Treasury, TributeToName: tributeToName, Tributes: tributes,
		Level: g.Level, BoostUntil: g.BoostUntil.Unix(),
		ShieldCooldownUntil: g.ShieldCooldownUntil.Unix(),
		WarCooldownUntil:    g.WarCooldownUntil.Unix(),
		UpgradeCost:         3000 + 1000*int64(g.Level),
		WarSettled:          g.WarSettledDay == now.In(ictZone).Format("2006-01-02"),
	}
}

func meGangID(p *Player) string {
	if p == nil {
		return ""
	}
	return p.GangID
}

func (s *Store) gangsLocked(me *Player) []GangView {
	out := make([]GangView, 0, len(s.gangs))
	for _, g := range s.gangs {
		out = append(out, s.gangViewLocked(g, me))
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Power > out[j].Power })
	for i := range out {
		switch {
		case i == 0:
			out[i].Tier = 1
		case i <= 2:
			out[i].Tier = 2
		default:
			out[i].Tier = 3
		}
	}
	return out
}

func (s *Store) Gangs(tok string) []GangView {
	s.mu.Lock()
	defer s.mu.Unlock()
	s.rollGangsLocked(time.Now())
	return s.gangsLocked(s.byToken[tok])
}

func (s *Store) Diplomacy(tok string) ([]GangView, []RelationEdge, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	me := s.byToken[tok]
	if me == nil {
		return nil, nil, errors.New("phiên đăng nhập hết hạn")
	}
	now := time.Now()
	s.rollGangsLocked(now)
	edges := make([]RelationEdge, 0)
	for _, g := range s.gangs {
		g.pruneRelations(now)
		for id, until := range g.Wars {
			if g.ID < id {
				edges = append(edges, RelationEdge{
					From: g.ID, To: id, Kind: "war", Until: until.Unix(),
				})
			}
		}
		for id, until := range g.Allies {
			if g.ID < id {
				edges = append(edges, RelationEdge{
					From: g.ID, To: id, Kind: "ally", Until: until.Unix(),
				})
			}
		}
		if g.TributeTo != "" {
			edges = append(edges, RelationEdge{
				From: g.ID, To: g.TributeTo, Kind: "tribute",
			})
		}
	}
	return s.gangsLocked(me), edges, nil
}

func (s *Store) CreateGang(tok, name string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	name = strings.TrimSpace(name)
	if utf8.RuneCountInString(name) < 3 || utf8.RuneCountInString(name) > 24 {
		return StateView{}, errors.New("tên băng phải 3–24 ký tự")
	}
	if p.GangID != "" {
		return StateView{}, errors.New("mày đang ở trong băng rồi")
	}
	for _, g := range s.gangs {
		if strings.EqualFold(g.Name, name) {
			return StateView{}, errors.New("tên băng đã có người xài")
		}
	}
	if p.Money < gangCreateCost {
		return StateView{}, errors.New("cần 2.000đ để lập băng")
	}
	p.Money -= gangCreateCost
	g := &Gang{
		ID: token(), Name: name, LeaderID: p.ID,
		Members:   []string{p.ID},
		Wars:      map[string]time.Time{},
		Allies:    map[string]time.Time{},
		CreatedAt: time.Now(),
	}
	p.GangID = g.ID
	s.gangs[g.ID] = g
	return s.stateLocked(p), nil
}

func (s *Store) JoinGang(tok, gangID string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if p.GangID != "" {
		return StateView{}, errors.New("mày đang ở trong băng rồi")
	}
	g := s.gangs[gangID]
	if g == nil {
		return StateView{}, errors.New("băng không tồn tại")
	}
	if len(g.Members) >= gangMaxMembers {
		return StateView{}, errors.New("băng đủ người rồi")
	}
	g.Members = append(g.Members, p.ID)
	p.GangID = g.ID
	return s.stateLocked(p), nil
}

func (s *Store) LeaveGang(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	g := s.gangs[p.GangID]
	if g == nil {
		return StateView{}, errors.New("mày chưa vào băng nào")
	}
	idx := -1
	for i, id := range g.Members {
		if id == p.ID {
			idx = i
		}
	}
	if idx >= 0 {
		g.Members = append(g.Members[:idx], g.Members[idx+1:]...)
	}
	p.GangID = ""
	if len(g.Members) == 0 {
		delete(s.gangs, g.ID)
		for _, other := range s.gangs {
			delete(other.Wars, g.ID)
			delete(other.Allies, g.ID)
			if other.TributeTo == g.ID {
				other.TributeTo = ""
			}
		}
	} else if g.LeaderID == p.ID {
		g.LeaderID = g.Members[0]
	}
	return s.stateLocked(p), nil
}

func (s *Store) gangPowerLocked(g *Gang) int {
	power := 0
	for _, id := range g.Members {
		if m := s.players[id]; m != nil {
			power += m.Power()
		}
	}
	return power
}

// gangTierLocked returns 1/2/3 matching the lobby ordering: strongest gang is
// tier 1, next two are tier 2, the rest tier 3.
func (s *Store) gangTierLocked(g *Gang) int {
	if g == nil {
		return 0
	}
	power := s.gangPowerLocked(g)
	higher := 0
	for _, other := range s.gangs {
		if other.ID == g.ID {
			continue
		}
		op := s.gangPowerLocked(other)
		if op > power || (op == power && other.ID < g.ID) {
			higher++
		}
	}
	switch {
	case higher == 0:
		return 1
	case higher <= 2:
		return 2
	default:
		return 3
	}
}

func (s *Store) DeclareWar(tok, gangID string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	now := time.Now()
	mine := s.gangs[p.GangID]
	if mine == nil {
		return StateView{}, errors.New("mày chưa có băng")
	}
	if mine.LeaderID != p.ID {
		return StateView{}, errors.New("chỉ băng trưởng mới được tuyên chiến")
	}
	target := s.gangs[gangID]
	if target == nil || target.ID == mine.ID {
		return StateView{}, errors.New("băng mục tiêu không hợp lệ")
	}
	if mine.allied(now, target.ID) {
		return StateView{}, errors.New("đang liên minh, cắt liên minh trước")
	}
	mine.pruneRelations(now)
	if len(mine.Wars) > 0 {
		return StateView{}, errors.New("băng đang có cuộc chiến, dứt điểm rồi hẵng tuyên chiến băng khác")
	}
	if now.Before(mine.WarCooldownUntil) {
		left := int(mine.WarCooldownUntil.Sub(now).Minutes()) + 1
		return StateView{}, fmt.Errorf("băng vừa dứt chiến, phải nghỉ %d phút mới tuyên chiến tiếp", left)
	}
	myPower := int64(s.gangPowerLocked(mine))
	targetPower := int64(s.gangPowerLocked(target))
	if targetPower < 1 {
		targetPower = 1
	}
	if myPower > targetPower*2 {
		return StateView{}, errors.New("băng mục tiêu yếu hơn nửa lực băng mày, kiếm băng ngang tầm mà chém")
	}
	until := now.Add(warDuration)
	mine.WarCooldownUntil = until.Add(warCooldown)
	mine.Wars[target.ID] = until
	target.Wars[mine.ID] = until

	if target.TributeTo == mine.ID {
		target.TributeTo = ""
	}
	if mine.TributeTo == target.ID {
		mine.TributeTo = ""
	}

	for allyID := range mine.Allies {
		ally := s.gangs[allyID]
		if ally == nil || ally.ID == target.ID {
			continue
		}
		if !ally.allied(now, target.ID) {
			ally.Wars[target.ID] = until
			target.Wars[ally.ID] = until
		}
	}
	for allyID := range target.Allies {
		ally := s.gangs[allyID]
		if ally == nil || ally.ID == mine.ID {
			continue
		}
		if !ally.allied(now, mine.ID) {
			ally.Wars[mine.ID] = until
			mine.Wars[ally.ID] = until
		}
	}
	return s.stateLocked(p), nil
}

func (s *Store) AllyGang(tok, gangID string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	now := time.Now()
	mine := s.gangs[p.GangID]
	if mine == nil {
		return StateView{}, errors.New("mày chưa có băng")
	}
	if mine.LeaderID != p.ID {
		return StateView{}, errors.New("chỉ băng trưởng mới được kết minh")
	}
	target := s.gangs[gangID]
	if target == nil || target.ID == mine.ID {
		return StateView{}, errors.New("băng mục tiêu không hợp lệ")
	}
	if mine.allied(now, target.ID) {
		return StateView{}, errors.New("đã liên minh rồi")
	}
	if mine.atWar(now, target.ID) {
		return StateView{}, errors.New("đang chiến, không kết minh được")
	}
	if mine.TributeTo == target.ID || target.TributeTo == mine.ID {
		return StateView{}, errors.New("đang có quan hệ cống nộp, không kết minh")
	}
	if len(mine.Allies) >= 2 || len(target.Allies) >= 2 {
		return StateView{}, errors.New("mỗi băng tối đa 2 đồng minh")
	}
	until := now.Add(7 * 24 * time.Hour)
	mine.Allies[target.ID] = until
	target.Allies[mine.ID] = until
	return s.stateLocked(p), nil
}

func (s *Store) UnallyGang(tok, gangID string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	mine := s.gangs[p.GangID]
	if mine == nil || mine.LeaderID != p.ID {
		return StateView{}, errors.New("chỉ băng trưởng mới được cắt liên minh")
	}
	target := s.gangs[gangID]
	if target == nil || !mine.allied(time.Now(), target.ID) {
		return StateView{}, errors.New("không có liên minh với băng này")
	}
	delete(mine.Allies, target.ID)
	delete(target.Allies, mine.ID)
	return s.stateLocked(p), nil
}

func (s *Store) DemandTribute(tok, gangID string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	now := time.Now()
	mine := s.gangs[p.GangID]
	if mine == nil {
		return StateView{}, errors.New("mày chưa có băng")
	}
	if mine.LeaderID != p.ID {
		return StateView{}, errors.New("chỉ băng trưởng mới được đòi cống nộp")
	}
	target := s.gangs[gangID]
	if target == nil || target.ID == mine.ID {
		return StateView{}, errors.New("băng mục tiêu không hợp lệ")
	}
	if target.TributeTo != "" {
		return StateView{}, errors.New("băng này đã nộp cống cho băng khác")
	}
	if mine.TributeTo != "" {
		return StateView{}, errors.New("băng mày đang nộp cống, không đi thu được")
	}
	if mine.atWar(now, target.ID) || mine.allied(now, target.ID) {
		return StateView{}, errors.New("đang chiến hoặc liên minh, không thu cống được")
	}
	if s.gangPowerLocked(mine) < s.gangPowerLocked(target)*6/5 {
		return StateView{}, errors.New("băng mày chưa đủ mạnh để bắt nó nộp")
	}
	tributes := 0
	for _, other := range s.gangs {
		if other.TributeTo == mine.ID {
			tributes++
		}
	}
	if tributes >= maxTributesPerGang {
		return StateView{}, errors.New("băng mày đã thu cống 2 băng, ăn dày quá rồi")
	}
	target.TributeTo = mine.ID
	if leader := s.players[target.LeaderID]; leader != nil {
		leader.addInbox(InboxMsg{
			ID: token(), Kind: "gang", At: now.Unix(),
			Text: fmt.Sprintf("Băng %s bắt đầu thu cống 10%% thu nhập", mine.Name),
		})
	}
	return s.stateLocked(p), nil
}

func (s *Store) BreakTribute(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	mine := s.gangs[p.GangID]
	if mine == nil || mine.LeaderID != p.ID {
		return StateView{}, errors.New("chỉ băng trưởng mới được cắt cống nộp")
	}
	if mine.TributeTo == "" {
		return StateView{}, errors.New("băng mày không nộp cống cho ai")
	}
	protector := s.gangs[mine.TributeTo]
	mine.TributeTo = ""
	if protector != nil {
		if leader := s.players[protector.LeaderID]; leader != nil {
			leader.addInbox(InboxMsg{
				ID: token(), Kind: "gang", At: time.Now().Unix(),
				Text: fmt.Sprintf("Băng %s không nộp cống nữa", mine.Name),
			})
		}
	}
	return s.stateLocked(p), nil
}

func (s *Store) Ranking(tok string) []RankRow {
	s.mu.Lock()
	defer s.mu.Unlock()
	me := s.byToken[tok]
	rows := make([]RankRow, 0, len(s.players))
	for _, p := range s.players {
		s.accrue(p, time.Now())
		rows = append(rows, RankRow{
			ID: p.ID, Bounty: p.Bounty, Name: p.Name, Rank: RankFor(p.Uy).Name, Uy: p.Uy,
			Power: p.Power(), Owned: p.OwnedCount(),
			IsMe: me != nil && p.ID == me.ID, Money: p.Money, Player: p.ID,
		})
	}
	sort.Slice(rows, func(i, j int) bool {
		if rows[i].Uy != rows[j].Uy {
			return rows[i].Uy > rows[j].Uy
		}
		return rows[i].Owned > rows[j].Owned
	})
	if len(rows) > 20 {
		rows = rows[:20]
	}
	return rows
}

func missionProgress(p *Player, def MissionDef) int {
	if def.Kind == "own" {
		return p.OwnedCount()
	}
	if def.Kind == "earn" {
		return int(p.Earned)
	}
	return p.Missions[def.Kind]
}

func missionViews(p *Player) []MissionView {
	out := make([]MissionView, 0, len(MissionDefs))
	for _, def := range MissionDefs {
		progress := missionProgress(p, def)
		claimable := !p.Claimed[def.ID] && progress >= def.Target
		out = append(out, MissionView{
			ID: def.ID, Title: def.Title, Desc: def.Desc,
			Progress: progress, Target: def.Target,
			RewardMoney: def.Money, RewardUy: def.Uy,
			Claimed: p.Claimed[def.ID], Claimable: claimable,
		})
	}
	return out
}

func (s *Store) ClaimMission(tok, id string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	var def *MissionDef
	for i := range MissionDefs {
		if MissionDefs[i].ID == id {
			def = &MissionDefs[i]
		}
	}
	if def == nil {
		return StateView{}, errors.New("nhiệm vụ không tồn tại")
	}
	if p.Claimed[id] {
		return StateView{}, errors.New("nhiệm vụ này nhận rồi")
	}
	if missionProgress(p, *def) < def.Target {
		return StateView{}, errors.New("chưa hoàn thành nhiệm vụ")
	}
	p.Claimed[id] = true
	p.Money += def.Money
	p.addUy(def.Uy)
	p.AddXP(25)
	return s.stateLocked(p), nil
}

func rollSkill() string {
	total := 0
	for _, def := range SkillDefs {
		total += def.Weight
	}
	n := mrand.Intn(total)
	for _, def := range SkillDefs {
		n -= def.Weight
		if n < 0 {
			return def.ID
		}
	}
	return SkillDefs[0].ID
}

func crewSkillViews(p *Player) []CrewSkillView {
	out := make([]CrewSkillView, 0, len(p.CrewSkills))
	for _, id := range p.CrewSkills {
		def := SkillByID(id)
		if def == nil {
			continue
		}
		out = append(out, CrewSkillView{
			ID: def.ID, Name: def.Name, Desc: def.Desc, Rarity: def.Rarity,
		})
	}
	return out
}

func minionGearViews(p *Player) []MinionGearView {
	out := make([]MinionGearView, 0, len(MinionGearDefs))
	for _, def := range MinionGearDefs {
		out = append(out, MinionGearView{
			ID: def.ID, Name: def.Name, Desc: def.Desc,
			Cost: def.Cost, Power: def.Power, Owned: p.Gear[def.ID],
		})
	}
	return out
}

func contractStateView(p *Player, now time.Time) *ContractView {
	if p.Contract == nil {
		return nil
	}
	v := contractView(p.Contract, p.contractProgress(p.Contract), now)
	return &v
}

func ownedItems(p *Player) []string {
	out := make([]string, 0, len(p.Items))
	for _, def := range ItemDefs {
		if p.Items[def.ID] {
			out = append(out, def.ID)
		}
	}
	return out
}

func (s *Store) bossLocked(now time.Time) *Boss {
	year, week := now.In(ictZone).ISOWeek()
	key := fmt.Sprintf("%d-W%02d", year, week)
	if s.boss == nil || s.boss.Week != key {
		s.boss = newBoss(now)
	}
	return s.boss
}

func (s *Store) bossViewLocked(p *Player, now time.Time) BossView {
	b := s.bossLocked(now)
	rows := make([]BossRow, 0, len(b.Damage))
	for id, dmg := range b.Damage {
		name := id
		if pl := s.players[id]; pl != nil {
			name = pl.Name
		}
		rows = append(rows, BossRow{Name: name, Damage: dmg})
	}
	sort.Slice(rows, func(i, j int) bool { return rows[i].Damage > rows[j].Damage })
	if len(rows) > 10 {
		rows = rows[:10]
	}
	return BossView{
		Week: b.Week, HP: max64(b.HP, 0), MaxHP: b.MaxHP,
		MyDamage: b.Damage[p.ID], Tickets: max(0, 3-p.Daily["boss"]),
		Defeated: b.HP <= 0, Top: rows,
	}
}

func (s *Store) Inbox(tok string) ([]InboxMsg, int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return nil, 0, err
	}
	s.accrue(p, time.Now())
	out := append([]InboxMsg(nil), p.Inbox...)
	return out, unreadCount(p), nil
}

func (s *Store) ReadInbox(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	for i := range p.Inbox {
		p.Inbox[i].Read = true
	}
	return s.stateLocked(p), nil
}

func (s *Store) Contracts(tok string) ([]ContractView, *ContractView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return nil, nil, err
	}
	s.accrue(p, time.Now())
	return contractOffers(p), contractStateView(p, time.Now()), nil
}

func (s *Store) AcceptContract(tok, id string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if p.Contract != nil {
		return StateView{}, errors.New("đang có hợp đồng rồi, xong đi")
	}
	var offer *ContractView
	offers := contractOffers(p)
	for i := range offers {
		if offers[i].ID == id {
			offer = &offers[i]
		}
	}
	if offer == nil {
		return StateView{}, errors.New("hợp đồng không tồn tại")
	}
	if p.Money < offer.Deposit {
		return StateView{}, errors.New("không đủ tiền đặt cọc")
	}
	duration := 15 * time.Minute
	if offer.ID == "c_bigwin" {
		duration = 20 * time.Minute
	}
	p.Money -= offer.Deposit
	var starts int64
	if offer.Kind == "earn" {
		starts = p.Earned
	} else {
		starts = int64(p.Missions["win"])
	}
	p.Contract = &Contract{
		ID: offer.ID, Title: offer.Title, Desc: offer.Desc, Kind: offer.Kind,
		Target: offer.Target, Deposit: offer.Deposit,
		RewardMoney: offer.RewardMoney, RewardUy: offer.RewardUy,
		Starts: starts, EndsAt: time.Now().Add(duration),
	}
	return s.stateLocked(p), nil
}

func (s *Store) ClaimContract(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	c := p.Contract
	if c == nil {
		return StateView{}, errors.New("không có hợp đồng nào")
	}
	if p.contractProgress(c) < c.Target {
		if time.Now().After(c.EndsAt) {
			return StateView{}, errors.New("hợp đồng đã hết hạn")
		}
		return StateView{}, errors.New("chưa xong hợp đồng")
	}
	p.Money += c.RewardMoney
	p.addUy(c.RewardUy)
	p.AddXP(60)
	p.addInbox(InboxMsg{
		ID: token(), Kind: "contract", At: time.Now().Unix(),
		Text: fmt.Sprintf("Xong hợp đồng %s: +%s, +%d uy", c.Title, formatVND(c.RewardMoney), c.RewardUy),
	})
	p.Contract = nil
	return s.stateLocked(p), nil
}

func (s *Store) CasinoPlay(tok, choice string, bet int64) (CasinoResult, StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return CasinoResult{}, StateView{}, err
	}
	s.accrue(p, time.Now())
	if p.Daily["casino"] >= 5 {
		return CasinoResult{}, StateView{}, errors.New("hết lượt sòng bạc hôm nay")
	}
	if choice != "tai" && choice != "xiu" {
		return CasinoResult{}, StateView{}, errors.New("chọn tài hoặc xỉu")
	}
	if bet < 100 {
		return CasinoResult{}, StateView{}, errors.New("cược tối thiểu 100đ")
	}
	if p.Money < bet {
		return CasinoResult{}, StateView{}, errors.New("không đủ tiền cược")
	}
	p.Daily["casino"]++
	p.Money -= bet
	roll := []int{mrand.Intn(6) + 1, mrand.Intn(6) + 1, mrand.Intn(6) + 1}
	sum := roll[0] + roll[1] + roll[2]
	win := false
	if sum != 3 && sum != 18 {
		if choice == "tai" && sum >= 11 {
			win = true
		}
		if choice == "xiu" && sum <= 10 {
			win = true
		}
	}
	res := CasinoResult{Roll: roll, Sum: sum, Win: win}
	if win {
		payout := bet * 19 / 10
		p.Money += payout
		res.Payout = payout
	}
	return res, s.stateLocked(p), nil
}

func (s *Store) BossInfo(tok string) (BossView, StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return BossView{}, StateView{}, err
	}
	s.accrue(p, time.Now())
	return s.bossViewLocked(p, time.Now()), s.stateLocked(p), nil
}

func (s *Store) BossHit(tok string) (BossHitResult, StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return BossHitResult{}, StateView{}, err
	}
	s.accrue(p, time.Now())
	b := s.bossLocked(time.Now())
	if b.HP <= 0 {
		return BossHitResult{}, StateView{}, errors.New("boss tuần này bị hạ rồi")
	}
	if p.Daily["boss"] >= 3 {
		return BossHitResult{}, StateView{}, errors.New("hết lượt đánh boss hôm nay")
	}
	p.Daily["boss"]++
	dmg := int64(p.Power()) * 3
	b.HP -= dmg
	b.Damage[p.ID] += dmg
	reward := dmg * 3
	uy := dmg / 40
	p.Money += reward
	p.addUy(uy)
	p.AddXP(10)
	if b.HP <= 0 {
		b.HP = 0
		p.addInbox(InboxMsg{
			ID: token(), Kind: "boss", At: time.Now().Unix(),
			Text: "Boss tuần này đã bị hạ. Tuần sau gặp lại.",
		})
	}
	return BossHitResult{Damage: dmg, Reward: reward, Uy: uy, BossHP: b.HP, Defeated: b.HP <= 0},
		s.stateLocked(p), nil
}

func (s *Store) BuyItem(tok, id string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	def := ItemByID(id)
	if def == nil {
		return StateView{}, errors.New("món đồ không tồn tại")
	}
	if p.Items[id] {
		return StateView{}, errors.New("mày có rồi")
	}
	if p.Money < def.Cost {
		return StateView{}, errors.New("không đủ tiền")
	}
	p.Money -= def.Cost
	p.Items[id] = true
	p.AddXP(10)
	return s.stateLocked(p), nil
}

func flipBrawlForDefender(res BrawlResult, defender *Player) BrawlResult {
	out := res
	out.Win = false
	out.Power = defender.Power()
	out.Defense = res.Power
	out.Reward = 0
	out.XP = 0
	out.Levelups = 0
	out.LevelupMoney = 0
	events := make([]BrawlEvent, len(res.Events))
	for i, e := range res.Events {
		ne := e
		ne.MyHp = e.EnemyHp
		ne.EnemyHp = e.MyHp
		if e.Side == "me" {
			ne.Side = "enemy"
		} else {
			ne.Side = "me"
		}
		events[i] = ne
	}
	out.Events = events
	return out
}

func (s *Store) DefenseBattle(tok, id string) (DefenseRecord, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return DefenseRecord{}, err
	}
	s.accrue(p, time.Now())
	for _, rec := range p.Defenses {
		if rec.ID == id {
			return rec, nil
		}
	}
	return DefenseRecord{}, errors.New("không tìm thấy trận này")
}

func (s *Store) UpgradeGang(tok, kind string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	g := s.gangs[p.GangID]
	if g == nil {
		return StateView{}, errors.New("mày chưa có băng")
	}
	if g.LeaderID != p.ID {
		return StateView{}, errors.New("chỉ băng trưởng mới tiêu quỹ")
	}
	switch kind {
	case "power":
		cost := 3000 + 1000*int64(g.Level)
		if g.Treasury < cost {
			return StateView{}, errors.New("quỹ băng không đủ")
		}
		g.Treasury -= cost
		g.Level++
	case "shield":
		if now := time.Now(); now.Before(g.ShieldCooldownUntil) {
			left := int(g.ShieldCooldownUntil.Sub(now).Minutes()) + 1
			return StateView{}, fmt.Errorf("khiên băng đang hồi, còn %d phút mới bật lại được", left)
		}
		if g.Treasury < 2500 {
			return StateView{}, errors.New("quỹ băng không đủ")
		}
		g.Treasury -= 2500
		until := time.Now().Add(30 * time.Minute)
		g.ShieldCooldownUntil = until.Add(shieldCooldown)
		for _, id := range g.Members {
			if m := s.players[id]; m != nil {
				m.ShieldUntil = until
			}
		}
	case "boost":
		if g.Treasury < 2000 {
			return StateView{}, errors.New("quỹ băng không đủ")
		}
		g.Treasury -= 2000
		g.BoostUntil = time.Now().Add(30 * time.Minute)
	default:
		return StateView{}, errors.New("loại nâng cấp không hợp lệ")
	}
	g.logLocked(fmt.Sprintf("%s tiêu quỹ: %s", p.Name, kind))
	return s.stateLocked(p), nil
}

// RaiseRacket: dằn mặt quán để ăn thêm 15% mỗi cấp, đổi lại tăng độ nóng.
func (s *Store) RaiseRacket(tok, id string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if p.Levels[id] <= 0 {
		return StateView{}, errors.New("quán này chưa mở")
	}
	level := p.Racket[id]
	if level >= 3 {
		return StateView{}, errors.New("quán này đã bảo kê tối đa")
	}
	cost := racketCost(level)
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền dằn mặt")
	}
	p.Money -= cost
	if p.Racket == nil {
		p.Racket = map[string]int{}
	}
	p.Racket[id] = level + 1
	p.Heat += 5
	if p.Heat > 100 {
		p.Heat = 100
	}
	p.HeatAt = time.Now()
	return s.stateLocked(p), nil
}

func (s *Store) RecruitGeneral(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if len(p.Generals) >= maxGenerals {
		return StateView{}, errors.New("chỉ nuôi được 3 tướng")
	}
	cost := generalRecruitCost(len(p.Generals))
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền mời tướng")
	}
	p.Money -= cost
	name := generalNames[mrand.Intn(len(generalNames))]
	for tries := 0; tries < 10; tries++ {
		used := false
		for _, g := range p.Generals {
			if g.Name == name {
				used = true
			}
		}
		if !used {
			break
		}
		name = generalNames[mrand.Intn(len(generalNames))]
	}
	a := SkillDefs[mrand.Intn(len(SkillDefs))]
	b := SkillDefs[mrand.Intn(len(SkillDefs))]
	for b.ID == a.ID {
		b = SkillDefs[mrand.Intn(len(SkillDefs))]
	}
	p.Generals = append(p.Generals, General{
		ID: token(), Name: name, Level: 1, SkillA: a.ID, SkillB: b.ID,
	})
	return s.stateLocked(p), nil
}

func (s *Store) TrainGeneral(tok, id string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	for i := range p.Generals {
		g := &p.Generals[i]
		if g.ID != id {
			continue
		}
		if g.Level >= 10 {
			return StateView{}, errors.New("tướng đã đạt cấp tối đa")
		}
		cost := generalTrainCost(g.Level)
		if p.Money < cost {
			return StateView{}, errors.New("không đủ tiền huấn luyện")
		}
		p.Money -= cost
		g.Level++
		return s.stateLocked(p), nil
	}
	return StateView{}, errors.New("không có tướng này")
}

// tickNPCsLocked: băng NPC kéo quân đòi lại đất sau khi bị chiếm,
// và thỉnh thoảng chiếm ô trống.
func (s *Store) tickNPCsLocked(now time.Time) {
	if now.Sub(s.npcTick) < time.Minute {
		return
	}
	s.npcTick = now
	keep := make([]npcRaid, 0, len(s.npcRaids))
	for _, r := range s.npcRaids {
		if r.At.After(now) {
			keep = append(keep, r)
			continue
		}
		if r.TerritoryID < 0 || r.TerritoryID >= len(s.territories) {
			continue
		}
		t := s.territories[r.TerritoryID]
		if t.OwnerID != r.TargetID {
			continue
		}
		owner := s.players[strings.TrimPrefix(r.TargetID, "p:")]
		if owner == nil {
			continue
		}
		def := s.defenseOf(t)
		if float64(def) < float64(npcPower[r.GangID])*(0.8+mrand.Float64()*0.6) {
			t.OwnerID = r.GangID
			t.OwnerName = npcGangs[r.GangID]
			delete(owner.Owned, r.TerritoryID)
			s.recalcLandLocked(owner)
			owner.addInbox(InboxMsg{
				ID: token(), Kind: "npc", At: now.Unix(), TerritoryID: r.TerritoryID,
				Text: fmt.Sprintf("%s kéo quân đòi lại %s. Đất đã mất.",
					npcGangs[r.GangID], t.Name),
			})
		} else {
			owner.addInbox(InboxMsg{
				ID: token(), Kind: "npc", At: now.Unix(), TerritoryID: r.TerritoryID,
				Text: fmt.Sprintf("%s kéo tới đòi %s nhưng bị đánh lui.",
					npcGangs[r.GangID], t.Name),
			})
		}
	}
	s.npcRaids = keep
	if mrand.Intn(100) < 8 {
		ids := make([]string, 0, len(npcGangs))
		for id := range npcGangs {
			ids = append(ids, id)
		}
		sort.Strings(ids)
		for _, t := range s.territories {
			if t.OwnerID != "" {
				continue
			}
			gid := ids[mrand.Intn(len(ids))]
			t.OwnerID = gid
			t.OwnerName = npcGangs[gid]
			break
		}
	}
}

type GangMemberView struct {
	ID   string `json:"id"`
	Name string `json:"name"`
	Role string `json:"role"`
}

type GangChatView struct {
	Messages []GangMsg        `json:"messages"`
	Members  []GangMemberView `json:"members"`
	MyRole   string           `json:"myRole"`
	Treasury int64            `json:"treasury"`
	Log      []GangLog        `json:"log"`
}

func gangRole(g *Gang, id string) string {
	if g.LeaderID == id {
		return "leader"
	}
	for _, o := range g.Officers {
		if o == id {
			return "officer"
		}
	}
	return "member"
}

func (g *Gang) logLocked(text string) {
	g.Log = append([]GangLog{{At: time.Now().Unix(), Text: text}}, g.Log...)
	if len(g.Log) > 30 {
		g.Log = g.Log[:30]
	}
}

func (s *Store) gangChatLocked(p *Player) GangChatView {
	g := s.gangs[p.GangID]
	if g == nil {
		return GangChatView{}
	}
	out := GangChatView{
		Messages: g.Chat, MyRole: gangRole(g, p.ID),
		Treasury: g.Treasury, Log: g.Log,
	}
	out.Members = make([]GangMemberView, 0, len(g.Members))
	for _, id := range g.Members {
		name := id
		if m := s.players[id]; m != nil {
			name = m.Name
		}
		out.Members = append(out.Members, GangMemberView{
			ID: id, Name: name, Role: gangRole(g, id),
		})
	}
	if out.Messages == nil {
		out.Messages = []GangMsg{}
	}
	if out.Log == nil {
		out.Log = []GangLog{}
	}
	return out
}

func (s *Store) GangChat(tok string) (GangChatView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return GangChatView{}, err
	}
	s.accrue(p, time.Now())
	if p.GangID == "" {
		return GangChatView{}, errors.New("mày chưa có băng")
	}
	return s.gangChatLocked(p), nil
}

func (s *Store) SendGangChat(tok, text string) (GangChatView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return GangChatView{}, err
	}
	s.accrue(p, time.Now())
	g := s.gangs[p.GangID]
	if g == nil {
		return GangChatView{}, errors.New("mày chưa có băng")
	}
	text = strings.TrimSpace(text)
	if text == "" {
		return GangChatView{}, errors.New("nói gì đi")
	}
	if utf8.RuneCountInString(text) > 200 {
		return GangChatView{}, errors.New("nói ngắn thôi, tối đa 200 ký tự")
	}
	g.Chat = append(g.Chat, GangMsg{
		ID: token(), At: time.Now().Unix(), Name: p.Name,
		Role: gangRole(g, p.ID), Text: text,
	})
	if len(g.Chat) > 50 {
		g.Chat = g.Chat[len(g.Chat)-50:]
	}
	return s.gangChatLocked(p), nil
}

func (s *Store) PromoteMember(tok, targetID string) (GangChatView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return GangChatView{}, err
	}
	s.accrue(p, time.Now())
	g := s.gangs[p.GangID]
	if g == nil {
		return GangChatView{}, errors.New("mày chưa có băng")
	}
	if g.LeaderID != p.ID {
		return GangChatView{}, errors.New("chỉ băng trưởng mới phong chức")
	}
	if targetID == p.ID {
		return GangChatView{}, errors.New("mày là băng trưởng rồi")
	}
	found := false
	for _, id := range g.Members {
		if id == targetID {
			found = true
		}
	}
	if !found {
		return GangChatView{}, errors.New("người này không ở trong băng")
	}
	for i, id := range g.Officers {
		if id == targetID {
			g.Officers = append(g.Officers[:i], g.Officers[i+1:]...)
			g.logLocked(fmt.Sprintf("%s bị bãi chức phó băng", s.playerName(targetID)))
			return s.gangChatLocked(p), nil
		}
	}
	g.Officers = append(g.Officers, targetID)
	g.logLocked(fmt.Sprintf("%s được phong phó băng", s.playerName(targetID)))
	return s.gangChatLocked(p), nil
}

func (s *Store) playerName(id string) string {
	if m := s.players[id]; m != nil {
		return m.Name
	}
	return id
}

func (s *Store) PayoutTreasury(tok string, amount int64) (GangChatView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return GangChatView{}, err
	}
	s.accrue(p, time.Now())
	g := s.gangs[p.GangID]
	if g == nil {
		return GangChatView{}, errors.New("mày chưa có băng")
	}
	if g.LeaderID != p.ID {
		return GangChatView{}, errors.New("chỉ băng trưởng mới chia quỹ")
	}
	if amount <= 0 {
		return GangChatView{}, errors.New("số tiền không hợp lệ")
	}
	if g.Treasury < amount {
		return GangChatView{}, errors.New("quỹ băng không đủ")
	}
	share := amount / int64(len(g.Members))
	if share <= 0 {
		return GangChatView{}, errors.New("chia ra mỗi người không đủ 1đ")
	}
	g.Treasury -= share * int64(len(g.Members))
	for _, id := range g.Members {
		if m := s.players[id]; m != nil {
			m.Money += share
			m.addInbox(InboxMsg{
				ID: token(), Kind: "gang", At: time.Now().Unix(),
				Text: fmt.Sprintf("Băng %s chia quỹ: +%dđ", g.Name, share),
			})
		}
	}
	g.logLocked(fmt.Sprintf("%s chia quỹ %dđ (%dđ/người)",
		p.Name, share*int64(len(g.Members)), share))
	return s.gangChatLocked(p), nil
}

func (s *Store) guardSlotsLocked(p *Player) []GuardSlot {
	out := make([]GuardSlot, 0, len(p.Guards))
	for i, t := range s.territories {
		if !p.Owned[i] {
			continue
		}
		out = append(out, GuardSlot{
			TerritoryID: i, Name: t.Name, Count: p.Guards[i], Tax: t.Tax,
		})
	}
	return out
}

func (s *Store) AssignGuard(tok string, territoryID, count int) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if !p.Owned[territoryID] {
		return StateView{}, errors.New("không phải địa bàn của mày")
	}
	if count < 0 {
		return StateView{}, errors.New("số quân không hợp lệ")
	}
	others := p.GuardsTotal() - p.Guards[territoryID]
	if others+count > p.Crew {
		return StateView{}, errors.New("không đủ đàn em để chia")
	}
	p.Guards[territoryID] = count
	return s.stateLocked(p), nil
}

func (s *Store) SetFormation(tok, kind string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	switch kind {
	case "balanced", "front", "sneak":
		p.Formation = kind
	default:
		return StateView{}, errors.New("đội hình không hợp lệ")
	}
	return s.stateLocked(p), nil
}

func (s *Store) BribeHeat(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	cost := p.BribeCost()
	if p.Heat <= 0 {
		return StateView{}, errors.New("mày đang sạch, không cần đút lót")
	}
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền đút lót")
	}
	p.Money -= cost
	p.Heat = 0
	p.HeatAt = time.Now()
	return s.stateLocked(p), nil
}

type BountyRow struct {
	ID     string `json:"id"`
	Name   string `json:"name"`
	Amount int64  `json:"amount"`
	Power  int    `json:"power"`
	Rank   string `json:"rank"`
}

func (s *Store) Bounties(tok string) []BountyRow {
	s.mu.Lock()
	defer s.mu.Unlock()
	out := make([]BountyRow, 0)
	for _, p := range s.players {
		if p.Bounty > 0 {
			out = append(out, BountyRow{
				ID: p.ID, Name: p.Name, Amount: p.Bounty,
				Power: p.Power(), Rank: RankFor(p.Uy).Name,
			})
		}
	}
	sort.Slice(out, func(i, j int) bool { return out[i].Amount > out[j].Amount })
	if len(out) > 10 {
		out = out[:10]
	}
	return out
}

func (s *Store) SetBounty(tok, targetID string, amount int64) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if targetID == p.ID {
		return StateView{}, errors.New("tự treo thưởng cho mình làm gì")
	}
	target := s.players[targetID]
	if target == nil {
		return StateView{}, errors.New("không tìm thấy tay chơi này")
	}
	if amount < 500 {
		return StateView{}, errors.New("treo tối thiểu 500đ")
	}
	if p.Money < amount {
		return StateView{}, errors.New("không đủ tiền treo thưởng")
	}
	p.Money -= amount
	target.Bounty += amount
	target.addInbox(InboxMsg{
		ID: token(), Kind: "bounty", At: time.Now().Unix(),
		Text: fmt.Sprintf("%s treo %s lên đầu mày", p.Name, formatVND(amount)),
	})
	return s.stateLocked(p), nil
}

func (s *Store) recalcLandLocked(p *Player) {
	total := 0.0
	var counts [4]int
	for id := range p.Owned {
		if id >= 0 && id < len(s.territories) {
			t := s.territories[id]
			total += float64(t.Tax) * (1 + 0.2*float64(t.Level)) * 0.15
			counts[DistrictOf(id)]++
		}
	}
	p.LandIncome = total
	// Giữ trọn cả quận (6 ô) = +10% thu nhập và +12 phòng thủ mỗi ô.
	held := 0
	for _, c := range counts {
		if c >= DistrictSize {
			held++
		}
	}
	p.DistrictCount = counts
	p.DistrictHeld = held
	p.DistrictBonus = 0.1 * float64(held)
}

func (s *Store) UpgradeTerritory(tok string, territoryID int) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if !p.Owned[territoryID] {
		return StateView{}, errors.New("không phải địa bàn của mày")
	}
	t := s.territories[territoryID]
	if t.Level >= 5 {
		return StateView{}, errors.New("địa bàn đã cấp tối đa")
	}
	cost := TerritoryUpgradeCost(t.Level)
	if p.Money < cost {
		return StateView{}, errors.New("không đủ tiền nâng địa bàn")
	}
	p.Money -= cost
	t.Level++
	s.recalcLandLocked(p)
	return s.stateLocked(p), nil
}

type ChapterView struct {
	ID          int    `json:"id"`
	Title       string `json:"title"`
	Desc        string `json:"desc"`
	BossName    string `json:"bossName"`
	BossPower   int    `json:"bossPower"`
	NeedOwned   int    `json:"needOwned"`
	NeedUy      int64  `json:"needUy"`
	RewardMoney int64  `json:"rewardMoney"`
	RewardUy    int64  `json:"rewardUy"`
	RewardXP    int64  `json:"rewardXp"`
	Status      string `json:"status"`
}

func (s *Store) Campaign(tok string) ([]ChapterView, int, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return nil, 0, err
	}
	s.accrue(p, time.Now())
	out := make([]ChapterView, 0, len(Chapters))
	for i, c := range Chapters {
		status := "locked"
		if i < p.Chapter {
			status = "cleared"
		} else if i == p.Chapter {
			status = "current"
		}
		out = append(out, ChapterView{
			ID: i, Title: c.Title, Desc: c.Desc, BossName: c.BossName,
			BossPower: c.BossPower, NeedOwned: c.NeedOwned, NeedUy: c.NeedUy,
			RewardMoney: c.RewardMoney, RewardUy: c.RewardUy, RewardXP: c.RewardXP,
			Status: status,
		})
	}
	return out, p.Chapter, nil
}

func (s *Store) FightChapter(tok string, index int) (BrawlResult, StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return BrawlResult{}, StateView{}, err
	}
	s.accrue(p, time.Now())
	if index != p.Chapter || index < 0 || index >= len(Chapters) {
		return BrawlResult{}, StateView{}, errors.New("chương này chưa mở")
	}
	c := Chapters[index]
	if p.OwnedCount() < c.NeedOwned || p.Uy < c.NeedUy {
		return BrawlResult{}, StateView{}, errors.New("chưa đủ điều kiện mở chương")
	}
	eff := p.AllEffects()
	crewForFight := p.AvailableCrew()
	power := p.Power() - p.GuardsTotal()*6
	if power < 10 {
		power = 10
	}
	hpMe := 150 + crewForFight*20 + eff.HpAdd + p.BonusHP() + p.GeneralHP()
	myHitDmg := int(float64(power/2+4) * (1 + eff.DmgMul))
	critEvery := eff.CritEvery
	if critEvery == 0 {
		critEvery = 3
	}
	if p.Formation == "front" {
		myHitDmg = myHitDmg * 115 / 100
		hpMe = hpMe * 9 / 10
	}
	if p.Formation == "sneak" {
		myHitDmg = myHitDmg * 9 / 10
		critEvery--
		if critEvery < 1 {
			critEvery = 1
		}
	}
	res := BrawlResult{Power: power, Defense: c.BossPower,
		TerritoryID: -(index + 1), TerritoryName: c.BossName}
	res.Events, res.Win = simulateBrawl(fighter{
		hp: hpMe, hitDmg: myHitDmg, critEvery: critEvery,
		dodgeEvery: eff.DodgeEvery, dr: p.DamageReduction(),
	}, fighter{hp: 120 + c.BossPower, hitDmg: c.BossPower/5 + 4, critEvery: 4})
	if res.Win {
		p.Chapter++
		p.Money += c.RewardMoney
		p.addUy(c.RewardUy)
		p.AddXP(c.RewardXP)
		res.Reward = c.RewardMoney
		res.UyGain = c.RewardUy
		res.XP = c.RewardXP
		text := fmt.Sprintf("Hạ %s, mở chương %d: %s", c.BossName,
			p.Chapter+1, Chapters[min(p.Chapter, len(Chapters)-1)].Title)
		if p.Chapter >= len(Chapters) {
			text = fmt.Sprintf("Hạ %s — phá xong cốt truyện! Sài Gòn là của mày. Giờ ra tù lấy Máu giang hồ rồi làm lại lớn hơn.", c.BossName)
		}
		p.addInbox(InboxMsg{
			ID: token(), Kind: "story", At: time.Now().Unix(),
			Text: text,
		})
	}
	return res, s.stateLocked(p), nil
}

func (s *Store) Prestige(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if p.Uy < 15000 {
		return StateView{}, errors.New("cần đạt 15.000 uy mới được ra tù")
	}
	for id := range p.Owned {
		if id >= 0 && id < len(s.territories) {
			s.territories[id].OwnerID = ""
			s.territories[id].OwnerName = ""
			s.territories[id].Level = 0
		}
	}
	p.Prestige++
	p.Money = 1000
	p.Uy = 0
	p.Level = 1
	p.XP = 0
	p.Points = 0
	p.Stats = map[string]int{}
	p.WeaponIdx = 0
	p.Crew = 0
	p.CrewSkills = []string{}
	p.Levels = map[string]int{"karaoke": 1, "matxa": 1, "baixe": 1}
	p.Owned = map[int]bool{}
	p.Guards = map[int]int{}
	p.Minions = 0
	p.Wounds = 0
	p.Gear = map[string]int{}
	p.WoundAt = time.Time{}
	p.Heat = 0
	p.Bounty = 0
	p.Missions = map[string]int{}
	p.Claimed = map[string]bool{}
	p.Daily = map[string]int{}
	p.DailyClaimed = map[string]bool{}
	p.Contract = nil
	p.Chapter = 0
	p.LandIncome = 0
	p.addInbox(InboxMsg{
		ID: token(), Kind: "prestige", At: time.Now().Unix(),
		Text: fmt.Sprintf("Ra tù lần %d — Máu giang hồ x%.1f", p.Prestige, p.PrestigeMultiplier()),
	})
	return s.stateLocked(p), nil
}

// MaxAccount đẩy tài khoản test lên mức cao nhất để thử nội dung cuối game.
func (s *Store) MaxAccount(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	p.Chapter = len(Chapters)
	p.Money = 5000000
	p.Uy = 30000
	p.Level = 40
	p.XP = 0
	p.Points = 40
	p.WeaponIdx = len(Weapons) - 1
	p.Crew = 4
	p.Minions = 24
	p.Racket = map[string]int{"karaoke": 2, "matxa": 1}
	p.DevUnlimited = true
	p.Heat = 0
	if len(p.Generals) == 0 {
		p.Generals = []General{
			{ID: token(), Name: "Tám Ngón", Level: 4, SkillA: "dao", SkillB: "ne"},
			{ID: token(), Name: "Bà Chị Hạnh", Level: 2, SkillA: "satthu", SkillB: "trau"},
		}
	}
	for _, b := range BusinessDefs {
		p.Levels[b.ID] = 5
	}
	held := 0
	for i := range s.territories {
		if held >= 8 {
			break
		}
		p.Owned[i] = true
		s.territories[i].OwnerID = "p:" + p.ID
		s.territories[i].OwnerName = p.Name
		if s.territories[i].Level < 3 {
			s.territories[i].Level = 3
		}
		held++
	}
	s.recalcLandLocked(p)
	p.addInbox(InboxMsg{
		ID: token(), Kind: "dev", At: time.Now().Unix(),
		Text: "Tài khoản test đã được đẩy lên mức cao nhất: xong cốt truyện, đủ uy ra tù, 8 địa bàn.",
	})
	return s.stateLocked(p), nil
}

// SetDevUnlimited bật/tắt chế độ đánh thoải mái cho tài khoản test:
// bỏ cooldown, độ nóng, trần địa bàn và khiên của mục tiêu.
func (s *Store) SetDevUnlimited(tok string, on bool) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	p.DevUnlimited = on
	if on {
		p.Heat = 0
	}
	return s.stateLocked(p), nil
}

// ResetTerritories trả toàn bộ địa bàn về trạng thái vô chủ để test combat.
func (s *Store) ResetTerritories(tok string) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	for i := range s.territories {
		s.territories[i].OwnerID = ""
		s.territories[i].OwnerName = ""
		s.territories[i].Level = 0
	}
	for _, pl := range s.players {
		pl.Owned = map[int]bool{}
		s.recalcLandLocked(pl)
	}
	return s.stateLocked(p), nil
}

// GrantTerritories cấp n địa bàn đầu tiên cho tài khoản test.
func (s *Store) GrantTerritories(tok string, count int) (StateView, error) {
	s.mu.Lock()
	defer s.mu.Unlock()
	p, err := s.player(tok)
	if err != nil {
		return StateView{}, err
	}
	s.accrue(p, time.Now())
	if count < 0 {
		count = 0
	}
	for i := 0; i < count && i < len(s.territories); i++ {
		p.Owned[i] = true
		s.territories[i].OwnerID = "p:" + p.ID
		s.territories[i].OwnerName = p.Name
	}
	s.recalcLandLocked(p)
	return s.stateLocked(p), nil
}

func max64(a, b int64) int64 {
	if a > b {
		return a
	}
	return b
}
