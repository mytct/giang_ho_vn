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
			CrewSkills:   []string{"dao", "trau", "maulieu", "ne"}[:min(crew, 4)],
			Levels:       map[string]int{"karaoke": 3, "matxa": 2, "baixe": 2, "nhau": 1},
			Owned:        map[int]bool{},
			Missions:     map[string]int{"win": 3, "upgrade": 2, "recruit": 1, "weapon": 1},
			Claimed:      map[string]bool{},
			DailyDay:     day,
			Daily:        map[string]int{"win": 2, "upgrade": 2, "earn": 3500},
			DailyClaimed: map[string]bool{},
			Items:        map[string]bool{"wave": true},
			Guards:       map[int]int{},
			Gear:         map[string]int{},
			Formation:    "balanced",
			HeatAt:       now,
			SeasonKey:    month,
			SeasonUy:     uy,
			LastAccrual:  now,
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

	a, tokA := mkPlayer("Đại Ca A", 7, 25000, 900, 2, 4, 2)
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
	a.Guards[0] = 1
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
	own(s.territories[0], a)
	own(s.territories[5], a)
	own(s.territories[1], c)
	own(s.territories[2], c)
	own(s.territories[3], c)
	own(s.territories[4], d)
	own(s.territories[6], e)
	own(s.territories[7], e)
	own(s.territories[8], e)
	a.Chapter = 1
	s.territories[0].Level = 2

	a.Contract = &Contract{
		ID: "c_win", Title: "Dằn mặt", Desc: "Thắng 2 trận trong 15 phút",
		Kind: "win", Target: 2, Deposit: 360,
		RewardMoney: 1900, RewardUy: 36,
		Starts: int64(a.Missions["win"]) - 1,
		EndsAt: now.Add(12 * time.Minute),
	}

	defenseID := token()
	a.Defenses = []DefenseRecord{{
		ID: defenseID, At: now.Add(-5 * time.Minute).Unix(),
		AttackerName: "Ó Đen", TerritoryID: 8, TerritoryName: "Chợ Đêm",
		Result: BrawlResult{
			Win: false, Power: a.Power(), Defense: e.Power(),
			TerritoryID: 8, TerritoryName: "Chợ Đêm",
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
		Text:         "Ó Đen chém mất Chợ Đêm của mày",
		FromName:     "Ó Đen",
		TerritoryID:  8,
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
		"Đại Ca A":  tokA,
		"Trùm C":    tokC,
		"Chuột Nhỏ": tokD,
		"Ó Đen":     tokE,
		"Lính Lẻ":   tokF,
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
