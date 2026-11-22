package main

import (
	"errors"
	"strings"
	"time"
)

var (
	demoSeeded bool
	demoTokens map[string]string
)

// SeedDemo creates a deterministic demo world with four gangs, diplomacy,
// owned territories, an active contract, inbox messages and claimable dailies.
func (s *Store) SeedDemo() map[string]string {
	s.mu.Lock()
	defer s.mu.Unlock()
	if s.demoSeeded && s.demoTokens != nil {
		return s.demoTokens
	}
	now := time.Now()
	day := now.In(ictZone).Format("2006-01-02")
	month := now.In(ictZone).Format("2006-01")

	mkPlayer := func(name string, level int, money, uy int64, weapon, crew, points int) (*Player, string) {
		p := &Player{
			ID: token(), Name: name, Money: money, Uy: uy,
			Level: level, XP: 10, Points: points,
			Stats:     map[string]int{"hp": 1, "dmg": 2},
			WeaponIdx: weapon, Crew: crew,
			CrewSkills:    []string{"dao", "trau", "maulieu", "ne"}[:min(crew, 4)],
			Biz:           map[int]map[string]int{HomeRegion(): {"karaoke": 3, "matxa": 2, "baixe": 2, "nhau": 1}},
			Owned:         map[int]bool{},
			Missions:      map[string]int{"win": 3, "upgrade": 2, "recruit": 1, "weapon": 1},
			Claimed:       map[string]bool{},
			DailyDay:      day,
			Daily:         map[string]int{"win": 2, "upgrade": 2, "earn": 3500},
			DailyClaimed:  map[string]bool{},
			Items:         map[string]bool{"wave": true},
			Guards:        map[int]int{},
			MinionGuards:  map[int]int{},
			GenGuards:     map[int]string{},
			Gear:          map[string]int{},
			Formation:     "balanced",
			DistrictCount: make([]int, len(Provinces)),
			RegionCount:   make([]int, len(RegionNames)),
			HeatAt:        now,
			SeasonKey:     month,
			SeasonUy:      uy,
			LastAccrual:   now,
		}
		t := token()
		s.players[p.ID] = p
		s.byToken[t] = p
		return p, t
	}

	mkGang := func(name string, leader *Player, members ...*Player) *Gang {
		g := &Gang{
			ID: token(), Name: name, LeaderID: leader.ID,
			Wars: map[string]time.Time{}, Allies: map[string]time.Time{},
			WarDay: day, CreatedAt: now,
		}
		g.Members = append(g.Members, leader.ID)
		leader.GangID = g.ID
		for _, m := range members {
			g.Members = append(g.Members, m.ID)
			m.GangID = g.ID
		}
		s.gangs[g.ID] = g
		return g
	}

	a, tokA := mkPlayer("Đại Ca A", 7, 25000, 2000, 2, 4, 2)
	b, _ := mkPlayer("Đệ B", 3, 8000, 300, 1, 2, 0)
	c, tokC := mkPlayer("Trùm C", 5, 15000, 600, 2, 3, 0)
	d, tokD := mkPlayer("Chuột Nhỏ", 2, 6000, 200, 1, 1, 0)
	e, tokE := mkPlayer("Ó Đen", 5, 18000, 700, 2, 3, 1)
	_, tokF := mkPlayer("Lính Lẻ", 2, 4000, 120, 0, 0, 0)
	a.Racket = map[string]int{"karaoke": 1, "matxa": 1}
	a.Generals = []General{
		{ID: token(), Name: "Tám Ngón", Level: 3, SkillA: "dao", SkillB: "ne"},
	}

	gangA := mkGang("Băng Rắn Độc", a, b)
	gangC := mkGang("Băng Cá Sấu", c)
	gangD := mkGang("Băng Chuột Cống", d)
	gangE := mkGang("Băng Ó Đen", e)

	untilAlly := now.Add(7 * 24 * time.Hour)
	gangA.Allies[gangC.ID] = untilAlly
	gangC.Allies[gangA.ID] = untilAlly

	untilWar := now.Add(25 * time.Minute)
	gangA.Wars[gangE.ID] = untilWar
	gangE.Wars[gangA.ID] = untilWar
	gangC.Wars[gangE.ID] = untilWar
	gangE.Wars[gangC.ID] = untilWar

	gangD.TributeTo = gangA.ID
	gangA.WarScore = 4
	gangC.WarScore = 2
	gangA.Treasury = 12000
	a.Heat = 45
	a.HeatAt = now
	homeBase := HomeProvince * DistrictSize
	a.Guards[homeBase] = 1
	a.MinionGuards[homeBase] = 10
	a.Minions = 120
	a.Wounds = 8
	a.WoundAt = now
	a.Gear["dao"] = 60
	a.Gear["kiem"] = 15
	e.Bounty = 3000
	c.Bounty = 1000

	own := func(t *Territory, p *Player) {
		t.OwnerID = "p:" + p.ID
		t.OwnerName = p.Name
		p.Owned[t.ID] = true
	}
	// Đại Ca A giữ trọn 12 quận Hồ Chí Minh: có thành, có công trình, có hàng.
	for k := 0; k < DistrictSize; k++ {
		own(s.territories[homeBase+k], a)
	}
	cBase := 15 * DistrictSize
	for k := 0; k < 3; k++ {
		own(s.territories[cBase+k], c)
	}
	dBase := 16 * DistrictSize
	for k := 0; k < 2; k++ {
		own(s.territories[dBase+k], d)
	}
	eBase := 17 * DistrictSize
	for k := 0; k < 3; k++ {
		own(s.territories[eBase+k], e)
	}
	a.Chapter = 1
	s.territories[homeBase].Level = 2
	a.Works = map[int]map[string]int{HomeProvince: {"cho": 2, "trai": 1, "song": 1}}
	a.Goods = 800

	// ---- Băng fake thêm cho thế giới đông đúc ----
	mx, tokMX := mkPlayer("Mắt Xanh", 8, 40000, 2600, 3, 5, 1)
	mx2, _ := mkPlayer("Sẹo Mặt", 6, 16000, 800, 2, 3, 0)
	mx3, _ := mkPlayer("Bạch Tuộc", 5, 14000, 650, 2, 3, 0)
	mx4, _ := mkPlayer("Cộn Tay", 4, 11000, 500, 2, 2, 0)
	mx5, _ := mkPlayer("Đao Phủ", 4, 10000, 450, 1, 2, 0)
	dc, _ := mkPlayer("Dao Cựa", 5, 15000, 550, 2, 3, 0)
	dc2, _ := mkPlayer("Răng Vàng", 4, 9000, 400, 1, 2, 0)
	dc3, _ := mkPlayer("Mút Gỗ", 3, 7000, 300, 1, 2, 0)
	lt, tokLT := mkPlayer("Lửa Thiêng", 6, 20000, 900, 3, 4, 0)
	lt2, _ := mkPlayer("Khói Thuốc", 4, 10000, 420, 2, 2, 0)
	md, _ := mkPlayer("Ma Da", 4, 12000, 480, 2, 2, 0)
	md2, _ := mkPlayer("Bóng Đêm", 3, 8000, 320, 1, 1, 0)
	sd, _ := mkPlayer("Sóng Đèo", 3, 9000, 350, 1, 2, 0)
	dm, _ := mkPlayer("Đêm Mưa", 2, 6000, 250, 1, 1, 0)

	gangMX := mkGang("Băng Mắt Xanh", mx, mx2, mx3, mx4, mx5)
	gangDC := mkGang("Băng Dao Cựa", dc, dc2, dc3)
	gangLT := mkGang("Băng Lửa Thiêng", lt, lt2)
	gangMD := mkGang("Băng Ma Da", md, md2)
	gangSD := mkGang("Băng Sóng Đèo", sd)
	gangDM := mkGang("Băng Đêm Mưa", dm)

	gangMX.Treasury = 45000
	gangMX.WarScore = 6
	gangDC.Treasury = 6000
	gangLT.Treasury = 9000
	gangLT.WarScore = 1
	gangMD.Treasury = 3000
	gangSD.Treasury = 1500
	gangDM.Treasury = 800
	lt.Bounty = 800

	// Mắt Xanh và Lửa Thiêng đang chém nhau.
	gangMX.Wars[gangLT.ID] = untilWar
	gangLT.Wars[gangMX.ID] = untilWar
	// Dao Cựa nộp cống cho Rắn Độc (băng chủ nhận tối đa 2 băng cống).
	gangDC.TributeTo = gangA.ID
	// Dao Cựa kết minh với Ma Da.
	gangDC.Allies[gangMD.ID] = untilAlly
	gangMD.Allies[gangDC.ID] = untilAlly

	// Địa bàn rải khắp miền cho các băng mới.
	mxBase := 18 * DistrictSize
	for k := 0; k < 4; k++ {
		own(s.territories[mxBase+k], mx)
	}
	dcBase := 21 * DistrictSize
	for k := 0; k < 2; k++ {
		own(s.territories[dcBase+k], dc)
	}
	ltBase := 20 * DistrictSize
	own(s.territories[ltBase], lt)
	own(s.territories[ltBase+1], lt2)
	mdBase := 22 * DistrictSize
	own(s.territories[mdBase], md)
	own(s.territories[mdBase+1], md2)
	own(s.territories[23*DistrictSize], sd)
	s.recalcLandLocked(mx)
	s.recalcLandLocked(dc)
	s.recalcLandLocked(lt)
	s.recalcLandLocked(md)
	s.recalcLandLocked(sd)

	a.Contract = &Contract{
		ID: "c_win", Title: "Dằn mặt", Desc: "Thắng 2 trận trong 15 phút",
		Kind: "win", Target: 2, Deposit: 360,
		RewardMoney: 1900, RewardUy: 36,
		Starts: int64(a.Missions["win"]) - 1,
		EndsAt: now.Add(12 * time.Minute),
	}

	defenseID := token()
	lostID := homeBase + 8
	lostName := s.territories[lostID].Name
	lostProv := s.territories[lostID].Province
	a.Defenses = []DefenseRecord{{
		ID: defenseID, At: now.Add(-5 * time.Minute).Unix(),
		AttackerName: "Ó Đen", TerritoryID: lostID, TerritoryName: lostName,
		Result: BrawlResult{
			Win: false, Power: a.Power(), Defense: e.Power(),
			TerritoryID: lostID, TerritoryName: lostName, TerritoryProvince: lostProv,
			Events: []BrawlEvent{
				{At: 0, Side: "enemy", Dmg: 18, MyHp: 250, EnemyHp: 300},
				{At: 380, Side: "me", Dmg: 12, MyHp: 250, EnemyHp: 288},
				{At: 760, Side: "enemy", Crit: true, Dmg: 31, MyHp: 219, EnemyHp: 288},
				{At: 1140, Side: "enemy", Dmg: 46, MyHp: 0, EnemyHp: 288},
			},
		},
	}}
	s.recalcLandLocked(a)
	s.recalcLandLocked(c)
	s.recalcLandLocked(d)
	s.recalcLandLocked(e)
	a.addInbox(InboxMsg{
		ID: token(), Kind: "attack", At: now.Add(-5 * time.Minute).Unix(),
		Text:         "Ó Đen chém mất " + s.territories[lostID].Label() + " của mày",
		FromName:     "Ó Đen",
		TerritoryID:  lostID,
		BattleID:     defenseID,
		RevengeUntil: now.Add(20 * time.Minute).Unix(),
	})
	a.addInbox(InboxMsg{
		ID: token(), Kind: "gang", At: now.Add(-20 * time.Minute).Unix(),
		Text: "Băng Chuột Cống bắt đầu nộp cống 10% thu nhập",
	})

	s.boss.Damage[a.ID] = 4200
	s.boss.Damage[c.ID] = 3100
	s.boss.Damage[e.ID] = 2200
	s.boss.HP = s.boss.MaxHP - 9500

	// Tài khoản demo được đánh thoải mái: bỏ cooldown, độ nóng, trần địa bàn.
	for _, p := range s.players {
		p.DevUnlimited = true
	}
	s.demoTokens = map[string]string{
		"Đại Ca A":   tokA,
		"Trùm C":     tokC,
		"Chuột Nhỏ":  tokD,
		"Ó Đen":      tokE,
		"Lính Lẻ":    tokF,
		"Mắt Xanh":   tokMX,
		"Lửa Thiêng": tokLT,
	}
	s.demoSeeded = true
	return s.demoTokens
}

// DevLogin returns a token for a seeded demo player. It seeds on first use.
func (s *Store) DevLogin(name string) (string, error) {
	tokens := s.SeedDemo()
	name = strings.TrimSpace(name)
	if name == "" {
		name = "Đại Ca A"
	}
	if tok, ok := tokens[name]; ok {
		return tok, nil
	}
	return "", errors.New("không có tài khoản demo này")
}
