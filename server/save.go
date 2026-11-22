package main

import (
	"encoding/json"
	"log"
	"os"
	"time"
)

// Snapshot: toàn bộ state ra 1 file JSON. Prototype chưa có DB — file này
// giúp tài khoản/đất/băng sống sót qua restart server. Marshal dùng tên
// field Go cho cả Player/Gang/Territory nên ghi-đọc tự khớp nhau.
type snapshot struct {
	Players     []*Player         `json:"players"`
	Tokens      map[string]string `json:"tokens"`
	Gangs       []*Gang           `json:"gangs"`
	Territories []*Territory      `json:"territories"`
	Boss        *Boss             `json:"boss"`
	DemoSeeded  bool              `json:"demoSeeded"`
	DemoTokens  map[string]string `json:"demoTokens"`
}

func (s *Store) Save(path string) {
	s.mu.Lock()
	defer s.mu.Unlock()
	snap := snapshot{
		Players:     make([]*Player, 0, len(s.players)),
		Tokens:      make(map[string]string, len(s.byToken)),
		Gangs:       make([]*Gang, 0, len(s.gangs)),
		Territories: s.territories,
		Boss:        s.boss,
		DemoSeeded:  s.demoSeeded,
		DemoTokens:  s.demoTokens,
	}
	for id, p := range s.players {
		if p == nil {
			continue
		}
		snap.Players = append(snap.Players, p)
		_ = id
	}
	for tok, p := range s.byToken {
		snap.Tokens[tok] = p.ID
	}
	for _, g := range s.gangs {
		if g != nil {
			snap.Gangs = append(snap.Gangs, g)
		}
	}
	data, err := json.Marshal(snap)
	if err != nil {
		log.Printf("save lỗi: %v", err)
		return
	}
	tmp := path + ".tmp"
	if err := os.WriteFile(tmp, data, 0o644); err != nil {
		log.Printf("save lỗi: %v", err)
		return
	}
	if err := os.Rename(tmp, path); err != nil {
		log.Printf("save lỗi: %v", err)
	}
}

func (s *Store) Load(path string) {
	data, err := os.ReadFile(path)
	if err != nil {
		return // chưa có save, bắt đầu thế giới mới
	}
	var snap snapshot
	if err := json.Unmarshal(data, &snap); err != nil {
		log.Printf("save hỏng (%v) — bắt đầu thế giới mới", err)
		return
	}
	s.mu.Lock()
	defer s.mu.Unlock()
	s.players = map[string]*Player{}
	s.byToken = map[string]*Player{}
	for _, p := range snap.Players {
		if p == nil || p.ID == "" {
			continue
		}
		s.players[p.ID] = p
	}
	for tok, pid := range snap.Tokens {
		if p := s.players[pid]; p != nil {
			s.byToken[tok] = p
		}
	}
	s.gangs = map[string]*Gang{}
	for _, g := range snap.Gangs {
		if g == nil || g.ID == "" {
			continue
		}
		if g.Wars == nil {
			g.Wars = map[string]time.Time{}
		}
		if g.Allies == nil {
			g.Allies = map[string]time.Time{}
		}
		s.gangs[g.ID] = g
	}
	// Đất chỉ nhận lại khi cấu trúc thế giới khớp (không đổi số tỉnh/quận).
	if len(snap.Territories) == len(s.territories) {
		for i, t := range snap.Territories {
			if t == nil {
				continue
			}
			*s.territories[i] = *t
		}
	} else {
		log.Printf("bỏ qua đất trong save: cấu trúc map đã đổi (%d vs %d ô)",
			len(snap.Territories), len(s.territories))
	}
	if snap.Boss != nil && snap.Boss.MaxHP > 0 {
		s.boss = snap.Boss
	}
	s.demoSeeded = snap.DemoSeeded
	s.demoTokens = snap.DemoTokens
	for _, p := range s.players {
		s.recalcLandLocked(p)
	}
	log.Printf("đã nạp save %s: %d người chơi, %d băng", path, len(s.players), len(s.gangs))
}
