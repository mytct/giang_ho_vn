package main

import (
	"errors"
	"log"
	"math/rand"
	"strings"
	"time"
)

type botPlayer struct {
	tok  string
	name string
}

var botNames = []string{
	"Bot Bố Cáo", "Bot Thằng Điên", "Bot Mèo Hoang", "Bot Cò Ke",
	"Bot Tư Đen", "Bot Đầu Bạc", "Bot Bà Ba", "Bot Hầm Heo",
}

var botGangNames = []string{"Băng Bão Cát", "Băng Răng Sún"}

// StartBots chạy n bot nền. Bot chơi đúng như người chơi thật: đăng nhập qua
// Login, dùng token gọi State/Attack/Recruit... nên trận chém là trận thật —
// có event, replay, hộp thư, truy nã, độ nóng, trần địa bàn, cooldown.
// Số bot: GIANGHO_BOTS=N, mặc định 6 khi GIANGHO_DEV bật, 0 khi tắt.
func (s *Store) StartBots(n int) {
	if n <= 0 {
		return
	}
	go func() {
		bots := make([]botPlayer, 0, n)
		for i := 0; i < n && i < len(botNames); i++ {
			p, tok, err := s.LoginOrRegister(strings.ToLower(botNames[i]), botNames[i])
			if err != nil {
				continue
			}
			// Chỉ cấp vốn lúc tạo mới — restart nạp save thì bot giữ tài sản.
			if p.Money <= 500 {
				s.botGrant(tok, 60000)
			}
			bots = append(bots, botPlayer{tok: tok, name: botNames[i]})
		}
		s.botSetupGangs(bots)
		log.Printf("bots online: %d", len(bots))
		if len(bots) < 2 {
			return
		}
		for {
			time.Sleep(time.Duration(2+rand.Intn(4)) * time.Second)
			b := bots[rand.Intn(len(bots))]
			if err := s.botAct(b); err != nil && !strings.Contains(err.Error(), "hết hạn") {
				// Bot im lặng thử việc khác lần sau — lỗi riêng tư của bot.
			}
		}
	}()
}

// botGrant cấp vốn khởi đầu: bot mô phỏng tay chơi đã chơi lâu, 500đ thì
// chỉ biết ngồi ôm cơ sở.
func (s *Store) botGrant(tok string, amount int64) {
	s.mu.Lock()
	defer s.mu.Unlock()
	if p, ok := s.byToken[tok]; ok {
		p.Money += amount
	}
}

// botSetupGangs: nửa bot lập 2 băng, còn lại chia vào 2 băng đó, rồi tuyên
// chiến nhau ngay để có PK băng vs băng.
func (s *Store) botSetupGangs(bots []botPlayer) {
	gangIDs := make([]string, 0, 2)
	for i, gname := range botGangNames {
		if i*2 >= len(bots) {
			break
		}
		if _, err := s.CreateGang(bots[i*2].tok, gname); err != nil {
			continue
		}
		if g, ok := s.botGangByName(gname); ok {
			gangIDs = append(gangIDs, g.ID)
		}
	}
	for i := range bots {
		if i%2 == 0 || len(gangIDs) == 0 {
			continue
		}
		gid := gangIDs[i/2%len(gangIDs)]
		_, _ = s.JoinGang(bots[i].tok, gid)
	}
	if len(gangIDs) == 2 {
		_, _ = s.DeclareWar(bots[0].tok, gangIDs[1])
	}
}

func (s *Store) botGangByName(name string) (*Gang, bool) {
	s.mu.Lock()
	defer s.mu.Unlock()
	for _, g := range s.gangs {
		if g.Name == name {
			return g, true
		}
	}
	return nil, false
}

// botAct: AI cực đơn giản — hạ nóng trước, sau đó chém hoặc tiêu tiền.
func (s *Store) botAct(b botPlayer) error {
	st, err := s.State(b.tok)
	if err != nil {
		return err
	}
	switch {
	case st.Heat >= 70 && st.Money >= st.BribeCost:
		_, err = s.BribeHeat(b.tok)
		return err
	case st.OwnedCount < st.MaxOwned && st.Power > 40 && rand.Intn(100) < 55:
		return s.botAttack(b, st)
	case st.Money > st.CrewCost*3:
		_, err = s.Recruit(b.tok)
		return err
	case st.NextWeapon != nil && st.Money > st.NextWeapon.Cost*2:
		_, err = s.UpgradeWeapon(b.tok)
		return err
	case st.Money > 40000:
		_, err = s.RecruitMinions(b.tok, 50)
		return err
	default:
		_, err = s.UpgradeBusiness(b.tok, "karaoke", HomeRegion())
		return err
	}
}

// botAttack: chém ô yếu nhất, ưu tiên đất người chơi (PK thật) hơn đất NPC.
func (s *Store) botAttack(b botPlayer, st StateView) error {
	territories, _, err := s.Map(b.tok)
	if err != nil {
		return err
	}
	best := -1
	bestDef := -1
	for _, t := range territories {
		if t.OwnerID == "" || t.OwnerID == "p:"+st.PlayerID {
			continue
		}
		if st.GangID != "" && t.OwnerGangID == st.GangID {
			continue // đất của băng mình
		}
		if t.Defense > st.Power {
			continue // không xanh thì thôi, bot không liều
		}
		def := t.Defense
		if strings.HasPrefix(t.OwnerID, "p:") {
			def -= 1000 // ưu tiên chém người chơi
		}
		if bestDef < 0 || def < bestDef {
			bestDef = def
			best = t.ID
		}
	}
	if best < 0 {
		return errors.New("bot không có mục tiêu")
	}
	res, _, err := s.Attack(b.tok, best)
	if err != nil {
		return err
	}
	target := tName(territories, best)
	if res.Win {
		log.Printf("🤖 %s chém %s: THẮNG (+%dđ, +%duy)", b.name, target, res.Reward, res.UyGain)
	} else {
		log.Printf("🤖 %s chém %s: THUA", b.name, target)
	}
	return nil
}

func tName(ts []Territory, id int) string {
	for _, t := range ts {
		if t.ID == id {
			return t.Label()
		}
	}
	return "?"
}
