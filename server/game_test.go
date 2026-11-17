package main

import (
	"testing"
	"time"
)

func newTestPlayer(t *testing.T) (*Store, string, *Player) {
	t.Helper()
	st := NewStore()
	p, tok, err := st.Login("Tý Hẻm")
	if err != nil {
		t.Fatalf("login: %v", err)
	}
	return st, tok, p
}

func TestLoginValidation(t *testing.T) {
	st := NewStore()
	if _, _, err := st.Login("A"); err == nil {
		t.Fatal("tên 1 ký tự phải bị từ chối")
	}
	if _, _, err := st.Login("  Tý  "); err != nil {
		t.Fatalf("tên hợp lệ bị từ chối: %v", err)
	}
}

func TestIncomeAccruesAndCaps(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	start, err := st.State(tok)
	if err != nil {
		t.Fatal(err)
	}
	if start.Rate <= 0 {
		t.Fatalf("tốc độ thu nhập phải > 0, got %v", start.Rate)
	}

	p.LastAccrual = time.Now().Add(-2 * time.Minute)
	after, _ := st.State(tok)
	want := int64(start.Rate * 120)
	if after.Money < start.Money+want-50 || after.Money > start.Money+want+50 {
		t.Fatalf("thu nhập 2 phút sai: trước %d, sau %d, rate %v", start.Money, after.Money, start.Rate)
	}

	p.LastAccrual = time.Now().Add(-48 * time.Hour)
	capped, _ := st.State(tok)
	capGain := int64(start.Rate * offlineCap.Seconds())
	if capped.Money > after.Money+capGain+100 {
		t.Fatalf("offline vượt trần 8h: %d", capped.Money-after.Money)
	}
}

func TestUpgradeBusiness(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 10000
	bizOf := func(s StateView) BusinessView {
		for _, b := range s.Businesses {
			if b.ID == "karaoke" && b.Region == HomeRegion() {
				return b
			}
		}
		t.Fatal("không thấy cơ sở ở vùng nhà")
		return BusinessView{}
	}
	before, _ := st.State(tok)
	cost := bizOf(before).UpgradeCost
	after, err := st.UpgradeBusiness(tok, "karaoke", HomeRegion())
	if err != nil {
		t.Fatalf("nâng cấp: %v", err)
	}
	if bizOf(after).Level != 2 {
		t.Fatalf("level phải là 2, got %d", bizOf(after).Level)
	}
	if after.Money != before.Money-cost {
		t.Fatalf("trừ tiền sai: %d -> %d, cost %d", before.Money, after.Money, cost)
	}
	if after.Rate <= before.Rate {
		t.Fatalf("nâng cấp phải tăng thu nhập")
	}
}

func TestRecruitAndAttackStrongEnough(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 1_000_000
	for i := 0; i < 3; i++ {
		if _, err := st.Recruit(tok); err != nil {
			t.Fatalf("mộ quân: %v", err)
		}
	}
	res, state, err := st.Attack(tok, 0)
	if err != nil {
		t.Fatalf("đánh: %v", err)
	}
	if len(res.Events) == 0 {
		t.Fatal("phải có diễn biến trận")
	}
	if !res.Win {
		t.Fatalf("3 đàn em phải thắng Hẻm 12 (power %d, defense %d)", res.Power, res.Defense)
	}
	if state.OwnedCount != 1 {
		t.Fatalf("phải chiếm được 1 địa bàn, got %d", state.OwnedCount)
	}
	if state.Uy <= 0 || state.Money <= 0 {
		t.Fatal("thắng phải có uy và tiền")
	}
}

func TestCannotAttackOwnTerritory(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 1_000_000
	for i := 0; i < 5; i++ {
		_, _ = st.Recruit(tok)
	}
	if _, _, err := st.Attack(tok, 0); err != nil {
		t.Fatal(err)
	}
	p.LastBrawl = time.Now().Add(-time.Minute)
	if _, _, err := st.Attack(tok, 0); err == nil {
		t.Fatal("không được đánh địa bàn của mình")
	}
}

func TestAttackCooldown(t *testing.T) {
	st, tok, _ := newTestPlayer(t)
	if _, _, err := st.Attack(tok, 1); err != nil {
		t.Fatalf("trận đầu: %v", err)
	}
	if _, _, err := st.Attack(tok, 1); err == nil {
		t.Fatal("phải có cooldown giữa 2 trận")
	}
}

func TestRankProgression(t *testing.T) {
	if RankFor(0).Name != "Con đỏ" {
		t.Fatal("uy 0 phải là Con đỏ")
	}
	if RankFor(2500).Name != "Đại ca" {
		t.Fatalf("uy 2500 phải là Đại ca, got %s", RankFor(2500).Name)
	}
	if next := NextRank(31000); next != nil {
		t.Fatal("uy 31000 đã là bậc cuối")
	}
}

func TestMissionRequiresProgressThenPaysOnce(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	if _, err := st.ClaimMission(tok, "muaso"); err == nil {
		t.Fatal("chưa nâng cấp thì không được nhận")
	}
	p.Money = 5000
	if _, err := st.UpgradeBusiness(tok, "karaoke", HomeRegion()); err != nil {
		t.Fatal(err)
	}
	before, _ := st.State(tok)
	after, err := st.ClaimMission(tok, "muaso")
	if err != nil {
		t.Fatalf("nhận thưởng: %v", err)
	}
	if after.Uy != before.Uy+20 {
		t.Fatalf("uy thưởng sai: %d -> %d", before.Uy, after.Uy)
	}
	if after.Money < before.Money+500 || after.Money > before.Money+560 {
		t.Fatalf("tiền thưởng sai: %d -> %d", before.Money, after.Money)
	}
	if _, err := st.ClaimMission(tok, "muaso"); err == nil {
		t.Fatal("không được nhận 2 lần")
	}
}

func TestMissionEarnAndOwnProgress(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.LastAccrual = time.Now().Add(-5 * time.Minute)
	state, _ := st.State(tok)
	var earn MissionView
	for _, m := range state.Missions {
		if m.ID == "thunhap" {
			earn = m
		}
	}
	if earn.Progress < 5000 || !earn.Claimable {
		t.Fatalf("nhiệm vụ kiếm tiền chưa đạt: %+v", earn)
	}
	if _, err := st.ClaimMission(tok, "thunhap"); err != nil {
		t.Fatalf("nhận thưởng kiếm tiền: %v", err)
	}

	p.Owned[0] = true
	p.Owned[1] = true
	p.Owned[2] = true
	state, _ = st.State(tok)
	var own MissionView
	for _, m := range state.Missions {
		if m.ID == "bangdang" {
			own = m
		}
	}
	if !own.Claimable || own.Progress != 3 {
		t.Fatalf("nhiệm vụ giữ địa bàn sai: %+v", own)
	}
}

func TestCrewSkillsRollAndAggregate(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 1_000_000
	for i := 0; i < 5; i++ {
		if _, err := st.Recruit(tok); err != nil {
			t.Fatalf("mộ quân: %v", err)
		}
	}
	if len(p.CrewSkills) != 5 {
		t.Fatalf("phải có 5 kỹ năng, got %d", len(p.CrewSkills))
	}
	for _, id := range p.CrewSkills {
		if SkillByID(id) == nil {
			t.Fatalf("kỹ năng lạ: %s", id)
		}
	}

	p.CrewSkills = []string{"dao", "trau", "ne", "maulieu", "momto"}
	eff := p.SkillEffects()
	if eff.DmgMul < 0.149 || eff.DmgMul > 0.151 {
		t.Fatalf("dmg mul sai: %v", eff.DmgMul)
	}
	if eff.HpAdd != 30 || eff.DodgeEvery != 4 || eff.CritEvery != 2 {
		t.Fatalf("hiệu ứng gộp sai: %+v", eff)
	}
	if eff.UyBonus != 25 {
		t.Fatalf("uy bonus sai: %d", eff.UyBonus)
	}

	res, _, err := st.Attack(tok, 19)
	if err != nil {
		t.Fatalf("đánh: %v", err)
	}
	miss := false
	for _, e := range res.Events {
		if e.Miss {
			miss = true
		}
	}
	if !miss {
		t.Fatal("có Né Đòn thì trận phải có ít nhất 1 đòn né")
	}
}

func TestStateIncludesCrewSkills(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 100000
	p.Crew = 2
	p.CrewSkills = []string{"dao", "satthu"}
	state, _ := st.State(tok)
	if len(state.CrewSkills) != 2 {
		t.Fatalf("state phải trả 2 kỹ năng, got %d", len(state.CrewSkills))
	}
	if state.CrewSkills[1].Rarity != "Đặc biệt" {
		t.Fatalf("độ hiếm sai: %+v", state.CrewSkills[1])
	}
}

func TestXPLevelUp(t *testing.T) {
	_, _, p := newTestPlayer(t)
	ups, money := p.AddXP(XPNeed(1) + XPNeed(2))
	if ups != 2 || p.Level != 3 {
		t.Fatalf("phải lên 2 cấp: ups=%d level=%d", ups, p.Level)
	}
	if p.Points != 2 {
		t.Fatalf("phải có 2 điểm, got %d", p.Points)
	}
	if want := int64(200*2 + 200*3); money != want {
		t.Fatalf("thưởng lên cấp sai: %d, want %d", money, want)
	}
	if p.XP != 0 {
		t.Fatalf("xp còn dư: %d", p.XP)
	}
}

func TestSpendPoint(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	if _, err := st.SpendPoint(tok, "hp"); err == nil {
		t.Fatal("0 điểm thì không chia được")
	}
	p.Points = 2
	state, err := st.SpendPoint(tok, "hp")
	if err != nil {
		t.Fatalf("chia điểm: %v", err)
	}
	if state.Stats["hp"] != 1 || state.Points != 1 {
		t.Fatalf("state sau chia điểm sai: %+v", state.Stats)
	}
	if p.BonusHP() != 25 {
		t.Fatalf("bonus máu sai: %d", p.BonusHP())
	}
	if _, err := st.SpendPoint(tok, "linh_tinh"); err == nil {
		t.Fatal("chỉ số lạ phải bị chặn")
	}
	p.Points = 1
	p.Stats["armor"] = 25
	if _, err := st.SpendPoint(tok, "armor"); err == nil {
		t.Fatal("giáp phải cap ở 25 điểm")
	}
}

func TestWinGivesXP(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 1_000_000
	for i := 0; i < 5; i++ {
		_, _ = st.Recruit(tok)
	}
	res, _, err := st.Attack(tok, 0)
	if err != nil {
		t.Fatal(err)
	}
	if !res.Win {
		t.Fatal("phải thắng để test xp")
	}
	if res.XP <= 0 {
		t.Fatalf("thắng phải có exp, got %d", res.XP)
	}
}

func TestDailyScalesWithLevel(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Level = 10
	state, _ := st.State(tok)
	byID := map[string]MissionView{}
	for _, m := range state.Daily {
		byID[m.ID] = m
	}
	if byID["d_win"].Target != 3 || byID["d_earn"].Target != 8000 || byID["d_upgrade"].Target != 3 {
		t.Fatalf("target daily sai: %+v", byID)
	}
	if byID["d_win"].RewardMoney != 1900 || byID["d_win"].RewardUy != 35 {
		t.Fatalf("thưởng daily sai: %+v", byID["d_win"])
	}
}

func TestDailyClaimAndReset(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 10000
	if _, err := st.UpgradeBusiness(tok, "karaoke", HomeRegion()); err != nil {
		t.Fatal(err)
	}
	if _, err := st.UpgradeBusiness(tok, "karaoke", HomeRegion()); err != nil {
		t.Fatal(err)
	}
	before, _ := st.State(tok)
	var up MissionView
	for _, m := range before.Daily {
		if m.ID == "d_upgrade" {
			up = m
		}
	}
	if !up.Claimable {
		t.Fatalf("nâng 2 lần phải xong nhiệm vụ ngày: %+v", up)
	}
	after, err := st.ClaimDaily(tok, "d_upgrade")
	if err != nil {
		t.Fatalf("nhận daily: %v", err)
	}
	if after.Uy != before.Uy+17 {
		t.Fatalf("uy thưởng daily sai: %d -> %d", before.Uy, after.Uy)
	}
	if _, err := st.ClaimDaily(tok, "d_upgrade"); err == nil {
		t.Fatal("không được nhận daily 2 lần")
	}

	p.DailyDay = "2000-01-01"
	p.DailyClaimed["d_upgrade"] = true
	reset, _ := st.State(tok)
	for _, m := range reset.Daily {
		if m.ID == "d_upgrade" && (m.Progress != 0 || m.Claimed) {
			t.Fatalf("sang ngày phải reset: %+v", m)
		}
	}
}

func TestTerritoryCapAndShield(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	cap := MaxTerritories(RankFor(p.Uy).Level)
	for i := 0; i < cap; i++ {
		p.Owned[i] = true
	}
	if _, _, err := st.Attack(tok, cap); err == nil {
		t.Fatalf("cấp Con đỏ chỉ giữ %d ô, phải bị chặn", cap)
	}

	b, _, err := st.Login("Bé Bảy")
	if err != nil {
		t.Fatal(err)
	}
	st.territories[0].OwnerID = "p:" + b.ID
	st.territories[0].OwnerName = b.Name
	st.territories[1].OwnerID = "p:" + b.ID
	st.territories[1].OwnerName = b.Name
	p.Owned = map[int]bool{}
	p.WeaponIdx = 3
	p.Money = 1_000_000
	for i := 0; i < 5; i++ {
		_, _ = st.Recruit(tok)
	}
	res, _, err := st.Attack(tok, 0)
	if err != nil {
		t.Fatal(err)
	}
	if !res.Win {
		t.Skip("không thắng được để test khiên")
	}
	if b.ShieldUntil.IsZero() {
		t.Fatal("mất địa bàn phải được khiên")
	}
	p.LastBrawl = time.Now().Add(-time.Minute)
	if _, _, err := st.Attack(tok, 1); err == nil {
		t.Fatal("khiên phải chặn đánh vào địa bàn còn lại")
	}
}

func TestNewbieProtectionAndIncomeCap(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	b, _, _ := st.Login("Tân Binh")
	st.territories[5].OwnerID = "p:" + b.ID
	p.Uy = 2500
	if _, _, err := st.Attack(tok, 5); err == nil {
		t.Fatal("uy cao không được đánh tân binh")
	}
	for i := 0; i < 12; i++ {
		p.Owned[i] = true
	}
	if p.TerritoryMultiplier() != 1.5 {
		t.Fatalf("hệ số địa bàn phải cap 1.5, got %v", p.TerritoryMultiplier())
	}
}

func TestGangAllyAndWar(t *testing.T) {
	st := NewStore()
	a, tokA, _ := st.Login("Đại Ca A")
	b, tokB, _ := st.Login("Đệ B")
	c, tokC, _ := st.Login("Trùm C")
	a.Money = 10000
	c.Money = 10000

	stateA, err := st.CreateGang(tokA, "Băng Rắn")
	if err != nil {
		t.Fatalf("lập băng: %v", err)
	}
	if stateA.GangName != "Băng Rắn" || stateA.GangMembers != 1 {
		t.Fatalf("state băng sai: %+v", stateA.GangName)
	}
	stateB, err := st.JoinGang(tokB, stateA.GangID)
	if err != nil {
		t.Fatalf("vào băng: %v", err)
	}
	if stateB.GangMembers != 2 {
		t.Fatalf("băng phải 2 người, got %d", stateB.GangMembers)
	}

	st.territories[0].OwnerID = "p:" + b.ID
	st.territories[0].OwnerName = b.Name
	if _, _, err := st.Attack(tokA, 0); err == nil {
		t.Fatal("đồng minh phải không đánh được")
	}

	stateC, err := st.CreateGang(tokC, "Băng Cá")
	if err != nil {
		t.Fatal(err)
	}
	if _, err := st.DeclareWar(tokB, stateC.GangID); err == nil {
		t.Fatal("chỉ băng trưởng mới được tuyên chiến")
	}
	if _, err := st.DeclareWar(tokA, stateC.GangID); err != nil {
		t.Fatalf("tuyên chiến: %v", err)
	}
	st.territories[1].OwnerID = "p:" + c.ID
	st.territories[1].OwnerName = c.Name
	if _, _, err := st.Attack(tokA, 1); err != nil {
		t.Fatalf("đang chiến thì phải đánh được: %v", err)
	}
}

func TestAttackInboxAndRevengeWindow(t *testing.T) {
	st, tokA, a := newTestPlayer(t)
	b, _, _ := st.Login("Bé Bảy")
	a.WeaponIdx = 3
	a.Money = 1_000_000
	for i := 0; i < 5; i++ {
		_, _ = st.Recruit(tokA)
	}
	st.territories[0].OwnerID = "p:" + b.ID
	st.territories[0].OwnerName = b.Name
	res, _, err := st.Attack(tokA, 0)
	if err != nil || !res.Win {
		t.Fatalf("phải thắng để test inbox: %v", err)
	}
	if len(b.Inbox) == 0 || b.Inbox[0].Kind != "attack" {
		t.Fatalf("nạn nhân phải nhận tin: %+v", b.Inbox)
	}
	if b.RevengeTarget != a.ID || b.RevengeUntil.IsZero() {
		t.Fatal("phải mở cửa sổ phản công")
	}
	if unreadCount(b) == 0 {
		t.Fatal("phải có tin chưa đọc")
	}
	state, err := st.ReadInbox(tokA)
	if err != nil || state.Unread != 0 {
		t.Fatalf("đọc hết tin sai: %+v %v", state.Unread, err)
	}
}

func TestContractFlow(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 20000
	offers, active, err := st.Contracts(tok)
	if err != nil || len(offers) != 3 || active != nil {
		t.Fatalf("offers sai: %v %v", offers, active)
	}
	state, err := st.AcceptContract(tok, "c_win")
	if err != nil {
		t.Fatalf("nhận hợp đồng: %v", err)
	}
	if state.Contract == nil || p.Money >= 20000 {
		t.Fatal("phải trừ cọc và có hợp đồng")
	}
	if _, err := st.AcceptContract(tok, "c_earn"); err == nil {
		t.Fatal("không được nhận 2 hợp đồng")
	}
	p.Missions["win"] += 10
	after, err := st.ClaimContract(tok)
	if err != nil {
		t.Fatalf("claim hợp đồng: %v", err)
	}
	if after.Contract != nil {
		t.Fatal("claim xong phải xoá hợp đồng")
	}
	if _, err := st.ClaimContract(tok); err == nil {
		t.Fatal("claim lần 2 phải lỗi")
	}
}

func TestContractExpiresLosesDeposit(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 20000
	if _, err := st.AcceptContract(tok, "c_earn"); err != nil {
		t.Fatal(err)
	}
	c := p.Contract
	c.EndsAt = time.Now().Add(-time.Minute)
	if _, err := st.State(tok); err != nil {
		t.Fatal(err)
	}
	if p.Contract != nil {
		t.Fatal("hết hạn phải huỷ hợp đồng")
	}
	found := false
	for _, m := range p.Inbox {
		if m.Kind == "contract" {
			found = true
		}
	}
	if !found {
		t.Fatal("phải có tin hợp đồng thất bại")
	}
}

func TestCasinoLimitAndBossTickets(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 100000
	for i := 0; i < 5; i++ {
		if _, _, err := st.CasinoPlay(tok, "tai", 100); err != nil {
			t.Fatalf("lượt %d: %v", i+1, err)
		}
	}
	if _, _, err := st.CasinoPlay(tok, "tai", 100); err == nil {
		t.Fatal("phải chặn lượt thứ 6")
	}
	for i := 0; i < 3; i++ {
		if _, _, err := st.BossHit(tok); err != nil {
			t.Fatalf("đánh boss %d: %v", i+1, err)
		}
	}
	if _, _, err := st.BossHit(tok); err == nil {
		t.Fatal("phải chặn lượt boss thứ 4")
	}
	boss, _, err := st.BossInfo(tok)
	if err != nil || boss.Tickets != 0 {
		t.Fatalf("boss view sai: %+v %v", boss, err)
	}
}

func TestItemPurchaseAndEffects(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	before := p.RatePerSec()
	p.Money = 50000
	state, err := st.BuyItem(tok, "wave")
	if err != nil {
		t.Fatalf("mua đồ: %v", err)
	}
	if len(state.Items) != 1 {
		t.Fatalf("phải có 1 món: %+v", state.Items)
	}
	if p.RatePerSec() <= before {
		t.Fatal("xe phải tăng thu nhập")
	}
	if _, err := st.BuyItem(tok, "wave"); err == nil {
		t.Fatal("không được mua trùng")
	}
}

func TestSeasonResetsMonthly(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.SeasonKey = "2000-01"
	p.SeasonUy = 9999
	state, _ := st.State(tok)
	if state.SeasonUy != 0 {
		t.Fatalf("sang tháng phải reset mùa: %d", state.SeasonUy)
	}
}

func makeGang(t *testing.T, st *Store, name, gangName string) (*Player, string, GangView) {
	t.Helper()
	p, tok, err := st.Login(name)
	if err != nil {
		t.Fatal(err)
	}
	p.Money = 10000
	state, err := st.CreateGang(tok, gangName)
	if err != nil {
		t.Fatalf("lập băng %s: %v", gangName, err)
	}
	for _, v := range st.Gangs(tok) {
		if v.ID == state.GangID {
			return p, tok, v
		}
	}
	t.Fatalf("không thấy băng %s", gangName)
	return nil, "", GangView{}
}

func TestAllianceBlocksAttackAndWarPullsAllies(t *testing.T) {
	st := NewStore()
	_, tokA, gangA := makeGang(t, st, "Đại Ca A", "Băng Rắn")
	b, _, _ := makeGang(t, st, "Đệ B", "Băng Chuột")
	c, tokC, gangC := makeGang(t, st, "Trùm C", "Băng Cá")

	if _, err := st.AllyGang(tokA, gangBID(st, "Băng Chuột")); err != nil {
		t.Fatalf("kết minh: %v", err)
	}
	st.territories[0].OwnerID = "p:" + b.ID
	st.territories[0].OwnerName = b.Name
	if _, _, err := st.Attack(tokA, 0); err == nil {
		t.Fatal("liên minh phải chặn đánh nhau")
	}

	if _, err := st.DeclareWar(tokC, gangA.ID); err != nil {
		t.Fatalf("tuyên chiến: %v", err)
	}
	gb := st.gangs[gangBID(st, "Băng Chuột")]
	if gb == nil || !gb.atWar(time.Now(), gangC.ID) {
		t.Fatal("đồng minh của A phải bị kéo vào chiến với C")
	}
	st.territories[1].OwnerID = "p:" + c.ID
	st.territories[1].OwnerName = c.Name
	b.LastBrawl = time.Now().Add(-time.Minute)
	if _, _, err := st.Attack(gangBTok(st, "Băng Chuột"), 1); err != nil {
		t.Fatalf("đang chiến thì phải đánh được: %v", err)
	}
}

func gangBID(st *Store, name string) string {
	for _, g := range st.gangs {
		if g.Name == name {
			return g.ID
		}
	}
	return ""
}

func gangBTok(st *Store, name string) string {
	id := gangBID(st, name)
	for tok, p := range st.byToken {
		if p.GangID == id {
			return tok
		}
	}
	return ""
}

func TestTributeIncomeAndBlock(t *testing.T) {
	st := NewStore()
	a, tokA, _ := makeGang(t, st, "Đại Ca A", "Băng Rắn")
	b, tokB, _ := makeGang(t, st, "Đệ B", "Băng Chuột")
	a.WeaponIdx = 3
	a.Money = 1_000_000
	for i := 0; i < 5; i++ {
		_, _ = st.Recruit(tokA)
	}
	if _, err := st.DemandTribute(tokA, gangBID(st, "Băng Chuột")); err != nil {
		t.Fatalf("đòi cống: %v", err)
	}
	if b.GangID == "" || st.gangs[b.GangID].TributeTo == "" {
		t.Fatal("băng yếu phải nộp cống")
	}
	before := st.gangs[a.GangID].Treasury
	b.LastAccrual = time.Now().Add(-2 * time.Minute)
	if _, err := st.State(tokB); err != nil {
		t.Fatal(err)
	}
	after := st.gangs[a.GangID].Treasury
	if after <= before {
		t.Fatalf("băng mạnh phải nhận cống: %d -> %d", before, after)
	}

	st.territories[0].OwnerID = "p:" + b.ID
	st.territories[0].OwnerName = b.Name
	if _, _, err := st.Attack(tokA, 0); err == nil {
		t.Fatal("không được đánh băng đang nộp cống")
	}
	if _, err := st.BreakTribute(tokB); err != nil {
		t.Fatalf("cắt cống: %v", err)
	}
	a.LastBrawl = time.Now().Add(-time.Minute)
	if _, _, err := st.Attack(tokA, 0); err != nil {
		t.Fatalf("cắt cống xong phải đánh được: %v", err)
	}
}

func TestGangTierAndRelation(t *testing.T) {
	st := NewStore()
	_, tokA, gangA := makeGang(t, st, "Đại Ca A", "Băng Rắn")
	makeGang(t, st, "B B", "Băng Chuột")
	makeGang(t, st, "C C", "Băng Cá")
	makeGang(t, st, "D D", "Băng Ó")
	rows := st.Gangs(tokA)
	if len(rows) != 4 {
		t.Fatalf("phải có 4 băng, got %d", len(rows))
	}
	if rows[0].Tier != 1 || rows[3].Tier != 3 {
		t.Fatalf("tier sai: %+v", rows)
	}
	for _, g := range rows {
		if g.ID == gangA.ID && g.Relation != "self" {
			t.Fatalf("băng mình phải relation self, got %s", g.Relation)
		}
	}
}

func TestDemoSeedWorld(t *testing.T) {
	st := NewStore()
	tokens := st.SeedDemo()
	tokA, ok := tokens["Đại Ca A"]
	if !ok {
		t.Fatal("thiếu token demo")
	}
	state, err := st.State(tokA)
	if err != nil {
		t.Fatal(err)
	}
	if state.Name != "Đại Ca A" || state.GangName != "Băng Rắn Độc" {
		t.Fatalf("state demo sai: %s / %s", state.Name, state.GangName)
	}
	if state.OwnedCount != DistrictSize {
		t.Fatalf("demo phải giữ trọn %d quận Hồ Chí Minh, got %d", DistrictSize, state.OwnedCount)
	}
	if state.DistrictHeld != 1 || len(state.Cities) != len(Provinces) {
		t.Fatalf("demo phải có 1 thành và đủ %d tỉnh, got held=%d cities=%d",
			len(Provinces), state.DistrictHeld, len(state.Cities))
	}
	home := state.Cities[HomeProvince]
	if !home.Mine || home.Works["cho"].Level != 2 {
		t.Fatalf("thành Hồ Chí Minh phải có chợ cấp 2: %+v", home)
	}
	if state.Unread < 2 {
		t.Fatalf("demo phải có tin chưa đọc, got %d", state.Unread)
	}
	if state.Contract == nil || state.Contract.Progress != 1 {
		t.Fatalf("demo phải có hợp đồng 1/2: %+v", state.Contract)
	}
	claimable := false
	for _, m := range state.Daily {
		if m.Claimable {
			claimable = true
		}
	}
	if !claimable {
		t.Fatal("demo phải có nhiệm vụ ngày nhận được")
	}

	rows := st.Gangs(tokA)
	if len(rows) != 4 {
		t.Fatalf("phải có 4 băng, got %d", len(rows))
	}
	if rows[0].Tier != 1 {
		t.Fatalf("băng mạnh nhất phải tier 1, got %d", rows[0].Tier)
	}
	rel := map[string]string{}
	for _, g := range rows {
		rel[g.Name] = g.Relation
	}
	if rel["Băng Cá Sấu"] != "ally" ||
		rel["Băng Chuột Cống"] != "tributary" ||
		rel["Băng Ó Đen"] != "war" {
		t.Fatalf("quan hệ demo sai: %+v", rel)
	}

	tok2, err := st.DevLogin("Đại Ca A")
	if err != nil || tok2 != tokA {
		t.Fatalf("dev login sai: %v", err)
	}
}

func TestDemoDiplomacyEdges(t *testing.T) {
	st := NewStore()
	tokens := st.SeedDemo()
	gangs, edges, err := st.Diplomacy(tokens["Đại Ca A"])
	if err != nil {
		t.Fatal(err)
	}
	if len(gangs) != 4 {
		t.Fatalf("phải 4 băng, got %d", len(gangs))
	}
	names := map[string]string{}
	for _, g := range gangs {
		names[g.ID] = g.Name
	}
	counts := map[string]int{}
	for _, e := range edges {
		counts[e.Kind]++
	}
	if counts["war"] < 2 || counts["ally"] < 1 || counts["tribute"] < 1 {
		t.Fatalf("thiếu cạnh ngoại giao: %+v", counts)
	}
	foundTribute := false
	for _, e := range edges {
		if e.Kind == "tribute" && names[e.To] == "Băng Rắn Độc" && names[e.From] == "Băng Chuột Cống" {
			foundTribute = true
		}
	}
	if !foundTribute {
		t.Fatalf("phải có cạnh cống nộp Chuột Cống -> Rắn Độc: %+v", edges)
	}
}

func TestWarSettlementRewardsOnce(t *testing.T) {
	st := NewStore()
	a, _, gangA := makeGang(t, st, "Đại Ca A", "Băng Rắn")
	b, _, gangB := makeGang(t, st, "Đệ B", "Băng Chuột")
	day := time.Now().In(ictZone).Format("2006-01-02")
	gA := st.gangs[gangA.ID]
	gB := st.gangs[gangB.ID]
	gA.WarDay = day
	gA.WarScore = 5
	gB.WarDay = day
	gB.WarScore = 1
	gA.WarSettledDay = ""
	gB.WarSettledDay = ""
	beforeA := a.Money
	beforeB := b.Money
	local := time.Now().In(ictZone)
	at := time.Date(local.Year(), local.Month(), local.Day(), 22, 30, 0, 0, ictZone)
	st.settleWarsLocked(at)
	if a.Money != beforeA+1000 {
		t.Fatalf("top 1 phải +1000, got %d", a.Money-beforeA)
	}
	if gA.Treasury != 5000 {
		t.Fatalf("quỹ top 1 phải +5000, got %d", gA.Treasury)
	}
	if b.Money != beforeB+600 {
		t.Fatalf("top 2 phải +600, got %d", b.Money-beforeB)
	}
	warMsg := false
	for _, m := range a.Inbox {
		if m.Kind == "war" {
			warMsg = true
		}
	}
	if !warMsg {
		t.Fatal("phải có tin thưởng chiến băng")
	}
	st.settleWarsLocked(at)
	if a.Money != beforeA+1000 {
		t.Fatal("không được thưởng 2 lần")
	}
}

func TestGangTreasurySpending(t *testing.T) {
	st := NewStore()
	_, tokA, gangA := makeGang(t, st, "Đại Ca A", "Băng Rắn")
	b, tokB, _ := makeGang(t, st, "Đệ B", "Băng Chuột")
	_ = b
	g := st.gangs[gangA.ID]
	g.Treasury = 10000

	state, err := st.UpgradeGang(tokA, "power")
	if err != nil {
		t.Fatalf("nâng lực băng: %v", err)
	}
	if g.Level != 1 || g.Treasury != 7000 || state.GangBonus <= 1.02 {
		t.Fatalf("nâng cấp băng sai: level %d quỹ %d bonus %v", g.Level, g.Treasury, state.GangBonus)
	}
	if _, err := st.UpgradeGang(tokB, "power"); err == nil {
		t.Fatal("không phải băng trưởng thì không được tiêu quỹ")
	}
	if _, err := st.UpgradeGang(tokA, "boost"); err != nil {
		t.Fatalf("mua boost: %v", err)
	}
	if !g.BoostUntil.After(time.Now()) {
		t.Fatal("boost phải có hiệu lực")
	}
	if _, err := st.UpgradeGang(tokA, "shield"); err != nil {
		t.Fatalf("mua khiên: %v", err)
	}
	if g.Members[0] != "" {
		if m := st.players[g.Members[0]]; m == nil || !m.ShieldUntil.After(time.Now()) {
			t.Fatal("khiên phải phủ thành viên")
		}
	}
	if _, err := st.UpgradeGang(tokA, "linh_tinh"); err == nil {
		t.Fatal("loại nâng cấp lạ phải bị chặn")
	}
}

func boostPlayerPower(p *Player) {
	p.WeaponIdx = 3
	p.Crew = 10
	p.Uy = 30000
}

func TestWarNeedsEvenMatchAndOneAtATime(t *testing.T) {
	st := NewStore()
	a, tokA, _ := makeGang(t, st, "Đại Ca A", "Băng Trùm")
	boostPlayerPower(a)
	c, _, _ := makeGang(t, st, "Trùm C", "Băng Cá")
	boostPlayerPower(c)
	d, _, _ := makeGang(t, st, "Trùm D", "Băng Ó")
	boostPlayerPower(d)
	makeGang(t, st, "Chuột Nhỏ", "Băng Yếu")

	if _, err := st.DeclareWar(tokA, gangBID(st, "Băng Yếu")); err == nil {
		t.Fatal("không được tuyên chiến băng yếu hơn nửa lực")
	}
	if _, err := st.DeclareWar(tokA, gangBID(st, "Băng Cá")); err != nil {
		t.Fatalf("tuyên chiến băng ngang tầm: %v", err)
	}
	if _, err := st.DeclareWar(tokA, gangBID(st, "Băng Ó")); err == nil {
		t.Fatal("đang có chiến tranh thì không được mở mặt trận mới")
	}

	g := st.gangs[a.GangID]
	past := time.Now().Add(-time.Minute)
	for id := range g.Wars {
		g.Wars[id] = past
	}
	g.pruneRelations(time.Now())
	if _, err := st.DeclareWar(tokA, gangBID(st, "Băng Ó")); err == nil {
		t.Fatal("vừa dứt chiến phải nghỉ cooldown")
	}
	g.WarCooldownUntil = time.Now().Add(-time.Minute)
	if _, err := st.DeclareWar(tokA, gangBID(st, "Băng Ó")); err != nil {
		t.Fatalf("hết cooldown phải tuyên chiến được: %v", err)
	}
}

func TestTributeCappedAtTwoGangs(t *testing.T) {
	st := NewStore()
	a, tokA, _ := makeGang(t, st, "Đại Ca A", "Băng Trùm")
	boostPlayerPower(a)
	makeGang(t, st, "Bé B", "Băng B")
	makeGang(t, st, "Bé C", "Băng C")
	makeGang(t, st, "Bé D", "Băng D")

	for _, name := range []string{"Băng B", "Băng C"} {
		if _, err := st.DemandTribute(tokA, gangBID(st, name)); err != nil {
			t.Fatalf("đòi cống %s: %v", name, err)
		}
	}
	if _, err := st.DemandTribute(tokA, gangBID(st, "Băng D")); err == nil {
		t.Fatal("chỉ được thu cống tối đa 2 băng")
	}
}

func TestGangShieldHasCooldown(t *testing.T) {
	st := NewStore()
	_, tokA, gangA := makeGang(t, st, "Đại Ca A", "Băng Rắn")
	g := st.gangs[gangA.ID]
	g.Treasury = 20000

	if _, err := st.UpgradeGang(tokA, "shield"); err != nil {
		t.Fatalf("bật khiên: %v", err)
	}
	if _, err := st.UpgradeGang(tokA, "shield"); err == nil {
		t.Fatal("khiên phải có cooldown, không bật liên tục được")
	}
	g.ShieldCooldownUntil = time.Now().Add(-time.Minute)
	if _, err := st.UpgradeGang(tokA, "shield"); err != nil {
		t.Fatalf("hết cooldown phải bật lại được: %v", err)
	}
}

func TestGangTierOrdering(t *testing.T) {
	st := NewStore()
	p1, _, g1 := makeGang(t, st, "Nhất", "Băng Nhất")
	p2, _, g2 := makeGang(t, st, "Nhì", "Băng Nhì")
	p3, _, g3 := makeGang(t, st, "Ba", "Băng Ba")
	p4, _, g4 := makeGang(t, st, "Bốn", "Băng Bốn")
	p1.Uy, p2.Uy, p3.Uy, p4.Uy = 30000, 20000, 10000, 0

	if got := st.gangTierLocked(st.gangs[g1.ID]); got != 1 {
		t.Fatalf("băng mạnh nhất phải tier 1, got %d", got)
	}
	if got := st.gangTierLocked(st.gangs[g2.ID]); got != 2 {
		t.Fatalf("băng nhì phải tier 2, got %d", got)
	}
	if got := st.gangTierLocked(st.gangs[g3.ID]); got != 2 {
		t.Fatalf("băng ba phải tier 2, got %d", got)
	}
	if got := st.gangTierLocked(st.gangs[g4.ID]); got != 3 {
		t.Fatalf("băng yếu nhất phải tier 3, got %d", got)
	}
}

func TestDefenseReplayAndFlip(t *testing.T) {
	st := NewStore()
	a, tokA, _ := makeGang(t, st, "Đại Ca A", "Băng Rắn")
	b, tokB, _ := makeGang(t, st, "Đệ B", "Băng Chuột")
	a.WeaponIdx = 3
	a.Money = 1_000_000
	for i := 0; i < 5; i++ {
		_, _ = st.Recruit(tokA)
	}
	st.territories[0].OwnerID = "p:" + b.ID
	st.territories[0].OwnerName = b.Name
	res, _, err := st.Attack(tokA, 0)
	if err != nil || !res.Win {
		t.Fatalf("phải thắng: %v", err)
	}
	if len(b.Defenses) != 1 {
		t.Fatalf("nạn nhân phải có 1 log, got %d", len(b.Defenses))
	}
	rec := b.Defenses[0]
	if rec.AttackerName != a.Name || rec.TerritoryName != st.territories[0].Name {
		t.Fatalf("log sai: %+v", rec)
	}
	if rec.Result.Win {
		t.Fatal("replay của nạn nhân phải là thua")
	}
	if rec.Result.Events[0].Side != "enemy" {
		t.Fatalf("đòn đầu phải đổi sang enemy, got %s", rec.Result.Events[0].Side)
	}
	got, err := st.DefenseBattle(tokB, rec.ID)
	if err != nil || got.ID != rec.ID {
		t.Fatalf("lấy replay: %v", err)
	}
	found := ""
	for _, m := range b.Inbox {
		if m.Kind == "attack" {
			found = m.BattleID
		}
	}
	if found != rec.ID {
		t.Fatalf("inbox phải gắn battleId, got %q", found)
	}
}

func TestGuardsSplitAndFormation(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 1_000_000
	for i := 0; i < 4; i++ {
		_, _ = st.Recruit(tok)
	}
	st.territories[0].OwnerID = "p:" + p.ID
	st.territories[0].OwnerName = p.Name
	p.Owned[0] = true

	state, err := st.AssignGuard(tok, 0, 2, 0)
	if err != nil {
		t.Fatalf("chia quân: %v", err)
	}
	if state.GuardsTotal != 2 || state.AvailableCrew != 2 {
		t.Fatalf("chia quân sai: %+v", state.Guards)
	}
	if _, err := st.AssignGuard(tok, 0, 9, 0); err == nil {
		t.Fatal("không được chia quá số quân")
	}
	if _, err := st.AssignGuard(tok, 1, 1, 0); err == nil {
		t.Fatal("không được giữ ô không phải của mình")
	}

	before := st.defenseOf(st.territories[0])
	if _, err := st.AssignGuard(tok, 0, 4, 0); err != nil {
		t.Fatal(err)
	}
	if st.defenseOf(st.territories[0]) <= before {
		t.Fatal("quân giữ đất phải tăng phòng thủ")
	}

	// Lính đông cũng chia canh giữ được và không còn đi chém.
	p.Minions = 100
	powerBefore := p.MinionPower()
	state, err = st.AssignGuard(tok, 0, 4, 40)
	if err != nil || state.GuardedMinions != 40 || state.AvailableMinions != 60 {
		t.Fatalf("chia lính giữ đất: %v %+v", err, state.GuardedMinions)
	}
	if p.MinionPower() >= powerBefore {
		t.Fatal("lính giữ đất phải bớt lực đi chém")
	}
	if _, err := st.AssignGuard(tok, 0, 4, 200); err == nil {
		t.Fatal("không được chia quá số lính khỏe")
	}

	state, err = st.SetFormation(tok, "front")
	if err != nil || state.Formation != "front" {
		t.Fatalf("đổi đội hình: %v", err)
	}
	if _, err := st.SetFormation(tok, "linh_tinh"); err == nil {
		t.Fatal("đội hình lạ phải bị chặn")
	}
}

func TestHeatPenaltyAndBribe(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	base := p.RatePerSec()
	p.Heat = 60
	p.HeatAt = time.Now()
	if p.RatePerSec() >= base {
		t.Fatal("nóng phải giảm thu nhập")
	}
	if p.BribeCost() != 4800 {
		t.Fatalf("giá đút lót sai: %d", p.BribeCost())
	}
	p.Money = 10000
	state, err := st.BribeHeat(tok)
	if err != nil {
		t.Fatalf("đút lót: %v", err)
	}
	if state.Heat != 0 || state.Money != 5200 {
		t.Fatalf("đút lót sai: heat %d money %d", state.Heat, state.Money)
	}
	if _, err := st.BribeHeat(tok); err == nil {
		t.Fatal("sạch rồi thì không đút được")
	}
	p.Heat = 85
	if _, _, err := st.Attack(tok, 0); err == nil {
		t.Fatal("nóng 80+ phải chặn chém")
	}
}

func TestBountySetAndCollect(t *testing.T) {
	st := NewStore()
	a, tokA, _ := st.Login("Đại Ca A")
	b, _, _ := st.Login("Bé B")
	a.Money = 1_000_000
	if _, err := st.SetBounty(tokA, b.ID, 1000); err != nil {
		t.Fatalf("treo thưởng: %v", err)
	}
	if a.Money != 999000 || b.Bounty != 1000 {
		t.Fatalf("treo thưởng trừ tiền sai: %d / %d", a.Money, b.Bounty)
	}
	rows := st.Bounties(tokA)
	if len(rows) != 1 || rows[0].ID != b.ID {
		t.Fatalf("bảng truy nã sai: %+v", rows)
	}
	if _, err := st.SetBounty(tokA, a.ID, 500); err == nil {
		t.Fatal("không được tự treo thưởng mình")
	}

	a.WeaponIdx = 3
	for i := 0; i < 5; i++ {
		_, _ = st.Recruit(tokA)
	}
	st.territories[0].OwnerID = "p:" + b.ID
	st.territories[0].OwnerName = b.Name
	res, _, err := st.Attack(tokA, 0)
	if err != nil || !res.Win {
		t.Fatalf("phải thắng: %v", err)
	}
	if res.Bounty != 1000 || b.Bounty != 0 {
		t.Fatalf("phải thu được tiền truy nã: %d / %d", res.Bounty, b.Bounty)
	}
}

func TestTerritoryUpgradeAddsIncomeAndDefense(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 10000
	p.Owned[0] = true
	st.territories[0].OwnerID = "p:" + p.ID
	st.territories[0].OwnerName = p.Name
	st.recalcLandLocked(p)
	beforeDef := st.defenseOf(st.territories[0])
	beforeIncome := p.LandIncome
	state, err := st.UpgradeTerritory(tok, 0)
	if err != nil {
		t.Fatalf("nâng địa bàn: %v", err)
	}
	if state.Money != 9400 {
		t.Fatalf("trừ tiền sai: %d", state.Money)
	}
	if st.territories[0].Level != 1 {
		t.Fatalf("level phải 1, got %d", st.territories[0].Level)
	}
	if p.LandIncome <= beforeIncome {
		t.Fatal("nâng ô phải tăng thu nhập đất")
	}
	if st.defenseOf(st.territories[0]) <= beforeDef {
		t.Fatal("nâng ô phải tăng phòng thủ")
	}
	if _, err := st.UpgradeTerritory(tok, 1); err == nil {
		t.Fatal("không được nâng ô không sở hữu")
	}
	for i := 0; i < 10; i++ {
		p.Money = 1_000_000
		_, _ = st.UpgradeTerritory(tok, 0)
	}
	if st.territories[0].Level != 5 {
		t.Fatalf("level phải cap 5, got %d", st.territories[0].Level)
	}
}

func TestCampaignChapterFlow(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 1_000_000
	p.WeaponIdx = 3
	for i := 0; i < 4; i++ {
		_, _ = st.Recruit(tok)
	}
	p.Owned[0] = true
	chapters, current, err := st.Campaign(tok)
	if err != nil || current != 0 || chapters[0].Status != "current" {
		t.Fatalf("campaign khởi đầu sai: %v %d", err, current)
	}
	res, state, err := st.FightChapter(tok, 0)
	if err != nil {
		t.Fatalf("đánh trùm: %v", err)
	}
	if !res.Win || state.Chapter != 1 {
		t.Fatalf("phải thắng mở chương: win=%v chapter=%d", res.Win, state.Chapter)
	}
	if state.Money <= p.Money-1000 || state.Uy == 0 {
		t.Fatal("phải có thưởng chương")
	}
	if _, _, err := st.FightChapter(tok, 0); err == nil {
		t.Fatal("chương cũ phải bị chặn")
	}
	if _, _, err := st.FightChapter(tok, 1); err == nil {
		t.Fatal("chương 2 chưa đủ điều kiện phải bị chặn")
	}
}

func TestPrestigeResetsAndMultiplies(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Uy = 16000
	p.Level = 8
	p.Crew = 3
	p.WeaponIdx = 2
	p.Owned[0] = true
	st.territories[0].OwnerID = "p:" + p.ID
	st.territories[0].OwnerName = p.Name
	st.territories[0].Level = 3
	p.Money = 50000
	state, err := st.Prestige(tok)
	if err != nil {
		t.Fatalf("ra tù: %v", err)
	}
	if state.Prestige != 1 || state.PrestigeMul < 1.09 {
		t.Fatalf("prestige sai: %+v", state.Prestige)
	}
	if state.Money != 1000 || state.Uy != 0 || state.Level != 1 || state.OwnedCount != 0 {
		t.Fatalf("reset chưa sạch: tiền %d uy %d level %d ô %d",
			state.Money, state.Uy, state.Level, state.OwnedCount)
	}
	if st.territories[0].OwnerID != "" || st.territories[0].Level != 0 {
		t.Fatal("địa bàn phải được thả về trống")
	}
	if p.WeaponIdx != 0 || p.Crew != 0 {
		t.Fatal("vũ khí/quân phải reset")
	}
	p.Uy = 100
	if _, err := st.Prestige(tok); err == nil {
		t.Fatal("uy thấp không được ra tù")
	}
}

func TestMinionRecruitGearHeal(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 1_000_000

	state, err := st.RecruitMinions(tok, 100)
	if err != nil || state.Minions != 100 {
		t.Fatalf("mộ lính: %v %+v", err, state.Minions)
	}
	if state.MinionPower != 50 {
		t.Fatalf("100 lính phải +50 lực, got %d", state.MinionPower)
	}
	state, err = st.BuyMinionGear(tok, "dao", 100)
	if err != nil || state.MinionPower != 150 {
		t.Fatalf("mua dao: %v power %d", err, state.MinionPower)
	}
	if _, err := st.BuyMinionGear(tok, "kiem", 1); err == nil {
		t.Fatal("không thể mua vũ khí nhiều hơn số lính")
	}

	p.applyWounds(20)
	if p.MinionHealthy() != 80 || p.MinionPower() != 120 {
		t.Fatalf("thương binh không được đánh: healthy %d power %d", p.MinionHealthy(), p.MinionPower())
	}
	state, err = st.HealMinions(tok, 10)
	if err != nil || state.Wounds != 10 {
		t.Fatalf("băng bó: %v wounds %d", err, state.Wounds)
	}
	if _, err := st.HealMinions(tok, 0); err != nil {
		t.Fatalf("băng bó toàn bộ: %v", err)
	}
	if p.Wounds != 0 {
		t.Fatalf("phải hết thương, còn %d", p.Wounds)
	}

	p.Minions = 490
	if _, err := st.RecruitMinions(tok, 100); err == nil {
		t.Fatal("không được vượt trần 500 lính")
	}
	if _, err := st.RecruitMinions(tok, 10); err != nil {
		t.Fatalf("mộ thêm trong trần: %v", err)
	}
}

func TestDevUnlimitedSkipsAttackLimits(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.DevUnlimited = true
	p.Heat = 100
	p.Money = 1_000_000
	for i := 0; i < DistrictSize; i++ {
		p.Owned[i] = true
		st.territories[i].OwnerID = "p:" + p.ID
	}
	if _, _, err := st.Attack(tok, 12); err != nil {
		t.Fatalf("dev unlimited phải bỏ qua cooldown/nóng/trần ô: %v", err)
	}
	if _, _, err := st.Attack(tok, 13); err != nil {
		t.Fatalf("phải đánh liên tiếp được: %v", err)
	}
}

func TestUpkeepDesertion(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 0
	p.Crew = 100
	p.LastAccrual = time.Now().Add(-time.Minute)
	if _, err := st.State(tok); err != nil {
		t.Fatal(err)
	}
	if p.Crew != 99 {
		t.Fatalf("thiếu lương phải mất 1 đàn em, còn %d", p.Crew)
	}
}

func TestRacketRaisesIncomeAndHeat(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 100000
	before := p.BusinessRate(BusinessDefs[0], HomeRegion())
	if _, err := st.RaiseRacket(tok, "karaoke"); err != nil {
		t.Fatal(err)
	}
	if p.Racket["karaoke"] != 1 {
		t.Fatalf("bảo kê phải lên cấp 1, got %d", p.Racket["karaoke"])
	}
	if p.BusinessRate(BusinessDefs[0], HomeRegion()) <= before {
		t.Fatal("bảo kê phải tăng thu nhập")
	}
	if p.Heat < 5 {
		t.Fatalf("dằn mặt phải tăng độ nóng, got %d", p.Heat)
	}
}

func TestDistrictBonusWhenHoldingWholeDistrict(t *testing.T) {
	st, _, p := newTestPlayer(t)
	p.Money = 100000
	base := HomeProvince * DistrictSize
	p.Owned[base] = true
	st.recalcLandLocked(p)
	one := p.BusinessRate(BusinessDefs[0], HomeRegion())
	for i := 1; i < DistrictSize; i++ {
		st.territories[base+i].OwnerID = "p:" + p.ID
		p.Owned[base+i] = true
	}
	st.recalcLandLocked(p)
	if p.DistrictHeld != 1 || p.DistrictBonus < 0.099 {
		t.Fatalf("giữ trọn tỉnh phải +10%%, held=%d bonus=%v", p.DistrictHeld, p.DistrictBonus)
	}
	if full := p.BusinessRate(BusinessDefs[0], HomeRegion()); full <= one {
		t.Fatalf("giữ trọn tỉnh phải tăng thu nhập: %v vs %v", full, one)
	}
	other := (HomeRegion() + 1) % len(RegionNames)
	if p.BusinessRate(BusinessDefs[0], other) != 0 {
		t.Fatal("vùng chưa giữ quận nào thì cơ sở không sinh thu nhập")
	}
}

func TestBusinessPerRegion(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 100000
	if _, err := st.UpgradeBusiness(tok, "karaoke", 0); err == nil {
		t.Fatal("chưa có quận ở Miền Bắc thì không được nâng cơ sở")
	}

	p.Owned[0] = true
	st.territories[0].OwnerID = "p:" + p.ID
	st.recalcLandLocked(p)
	for i := 0; i < 2; i++ {
		if _, err := st.UpgradeBusiness(tok, "karaoke", 0); err != nil {
			t.Fatalf("nâng cơ sở Miền Bắc: %v", err)
		}
	}
	if p.BizLevel(0, "karaoke") != 2 || p.BizLevel(HomeRegion(), "karaoke") != 1 {
		t.Fatalf("chỉ vùng Miền Bắc lên cấp: bắc=%d nhà=%d",
			p.BizLevel(0, "karaoke"), p.BizLevel(HomeRegion(), "karaoke"))
	}
	if p.BusinessRate(BusinessDefs[0], 0) <= p.BusinessRate(BusinessDefs[0], HomeRegion()) {
		t.Fatal("vùng có đất phải ăn hơn vùng không có quận")
	}
}

func TestGeneralsAndGangChat(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 100000
	p.Uy = 5000
	if _, err := st.RecruitGeneral(tok); err != nil {
		t.Fatal(err)
	}
	if len(p.Generals) != 1 || p.GeneralPower() <= 0 {
		t.Fatalf("mời tướng hỏng: %+v", p.Generals)
	}
	gen := p.Generals[0]
	if _, err := st.TrainGeneral(tok, gen.ID); err != nil {
		t.Fatal(err)
	}
	if p.Generals[0].Level != 2 {
		t.Fatalf("huấn luyện không lên cấp: %d", p.Generals[0].Level)
	}

	if _, err := st.CreateGang(tok, "Băng Test"); err != nil {
		t.Fatal(err)
	}
	g := st.gangs[p.GangID]
	g.Treasury = 900
	p.Money = 0
	chat, err := st.SendGangChat(tok, "anh em điểm danh")
	if err != nil || len(chat.Messages) != 1 {
		t.Fatalf("chat băng: %v %+v", err, chat)
	}
	if _, err := st.PayoutTreasury(tok, 900); err != nil {
		t.Fatal(err)
	}
	if p.Money != 900 || g.Treasury != 0 {
		t.Fatalf("chia quỹ sai: money=%d treasury=%d", p.Money, g.Treasury)
	}
	if chat := st.gangs[p.GangID]; len(chat.Log) == 0 {
		t.Fatal("chia quỹ phải ghi log")
	}
}

func TestNPCRetakesTerritory(t *testing.T) {
	st, _, p := newTestPlayer(t)
	st.territories[0].OwnerID = "p:" + p.ID
	st.territories[0].OwnerName = p.Name
	p.Owned[0] = true
	st.recalcLandLocked(p)
	st.npcRaids = []npcRaid{{
		GangID: "npc:ran", TargetID: "p:" + p.ID, TerritoryID: 0,
		At: time.Now().Add(-time.Minute),
	}}
	st.npcTick = time.Now().Add(-2 * time.Minute)
	st.tickNPCsLocked(time.Now())
	if st.territories[0].OwnerID != "npc:ran" || p.Owned[0] {
		t.Fatalf("NPC phải đòi lại đất: owner=%s owned=%v",
			st.territories[0].OwnerID, p.Owned[0])
	}
}

func TestBrawlVarianceAndDefenderSkills(t *testing.T) {
	firstHits := map[int]bool{}
	for i := 0; i < 30; i++ {
		evs, _ := simulateBrawl(
			fighter{hp: 600, hitDmg: 100, critEvery: 3},
			fighter{hp: 600, hitDmg: 100, critEvery: 4, dodgeEvery: 2},
		)
		firstHits[evs[0].Dmg] = true
		for _, e := range evs {
			if e.Dmg < 1 && !e.Miss {
				t.Fatalf("sát thương phải >= 1: %+v", e)
			}
		}
	}
	if len(firstHits) < 2 {
		t.Fatalf("sát thương phải dao động, chỉ thấy %v", firstHits)
	}

	taken := func(dr float64) int {
		evs, _ := simulateBrawl(
			fighter{hp: 1 << 20, hitDmg: 100, critEvery: 3, dr: dr},
			fighter{hp: 1 << 20, hitDmg: 100, critEvery: 4},
		)
		sum := 0
		for _, e := range evs {
			if e.Side == "enemy" && !e.Miss {
				sum += e.Dmg
			}
		}
		return sum
	}
	full, half := taken(0), taken(0.5)
	if half >= full*3/5 {
		t.Fatalf("giáp 50%% phải giảm sát thương nhận vào: %d vs %d", half, full)
	}

	st := NewStore()
	_, tokA, _ := st.Login("Đại Ca A")
	b, _, _ := st.Login("Đệ B")
	b.CrewSkills = []string{"ne"}
	st.territories[0].OwnerID = "p:" + b.ID
	st.territories[0].OwnerName = b.Name
	res, _, err := st.Attack(tokA, 0)
	if err != nil {
		t.Fatalf("đánh: %v", err)
	}
	missed := false
	for _, e := range res.Events {
		if e.Side == "me" && e.Miss {
			missed = true
		}
	}
	if !missed {
		t.Fatal("chủ địa bàn có Né Đòn phải né được đòn của mình")
	}
}

func TestMinionsGetWoundedInBattle(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 1_000_000
	if _, err := st.RecruitMinions(tok, 100); err != nil {
		t.Fatal(err)
	}
	res, _, err := st.Attack(tok, 0)
	if err != nil {
		t.Fatalf("đánh: %v", err)
	}
	if res.Wounded < 1 || p.Wounds < 1 {
		t.Fatalf("đánh nhau phải có lính bị thương: %+v", res)
	}
	if p.MinionPower() >= 50 {
		t.Fatal("thương binh phải làm giảm lực")
	}
}

func TestContestWindowAfterCapture(t *testing.T) {
	st, tokA, a := newTestPlayer(t)
	b, tokB, err := st.Login("Đại Ca B")
	if err != nil {
		t.Fatal(err)
	}
	st.territories[5].OwnerID = "p:" + b.ID
	st.territories[5].OwnerName = b.Name
	b.Owned[5] = true
	b.Uy = 500
	st.recalcLandLocked(b)

	a.Money = 1_000_000
	a.Uy = 20000
	a.Crew = 5
	a.DevUnlimited = true
	res, _, err := st.Attack(tokA, 5)
	if err != nil {
		t.Fatalf("đánh: %v", err)
	}
	if !res.Win {
		t.Fatalf("phải thắng: power %d defense %d", res.Power, res.Defense)
	}

	t5 := st.territories[5]
	if t5.PrevOwnerID != "p:"+b.ID || !t5.Contested(time.Now()) {
		t.Fatalf("đất mới chiếm phải ở trạng thái tranh chấp: %+v", t5)
	}
	contested := st.defenseOf(t5)
	t5.ContestedAt = 0
	if full := st.defenseOf(t5); contested >= full {
		t.Fatalf("trong 5 phút phòng thủ phải yếu hơn: %d vs %d", contested, full)
	}

	// Chủ cũ phải đánh lại được ngay trong cửa sổ 5 phút.
	b.DevUnlimited = true
	if _, _, err := st.Attack(tokB, 5); err != nil {
		t.Fatalf("chủ cũ phải phản công được: %v", err)
	}
}

// holdCity giao trọn một tỉnh cho p.
func holdCity(st *Store, p *Player, province int) {
	for i := province * DistrictSize; i < (province+1)*DistrictSize; i++ {
		st.territories[i].OwnerID = "p:" + p.ID
		st.territories[i].OwnerName = p.Name
		p.Owned[i] = true
	}
	st.recalcLandLocked(p)
}

func TestBuildWorkNeedsLand(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Money = 100000
	province := (HomeProvince + 1) % len(Provinces)
	if _, err := st.BuildWork(tok, province, "cho"); err == nil {
		t.Fatal("chưa có quận ở tỉnh này thì không xây được")
	}
	if _, err := st.BuildWork(tok, province, "bida"); err == nil {
		t.Fatal("công trình lạ phải bị từ chối")
	}

	holdCity(st, p, province)
	before := p.Money
	after, err := st.BuildWork(tok, province, "cho")
	if err != nil {
		t.Fatalf("xây chợ: %v", err)
	}
	if after.Cities[province].Works["cho"].Level != 1 {
		t.Fatalf("chợ phải cấp 1, got %+v", after.Cities[province].Works["cho"])
	}
	if p.Money != before-WorkCost(WorkDefs[0], 0) {
		t.Fatalf("trừ tiền sai: %d -> %d", before, p.Money)
	}
	if after.GoodsRate <= goodsPerOwned*float64(p.OwnedCount()) {
		t.Fatalf("chợ phải tăng hàng/giây, got %v", after.GoodsRate)
	}
}

func TestWorkEffectsOnlyWhileHoldingCity(t *testing.T) {
	st, _, p := newTestPlayer(t)
	p.Money = 100000
	holdCity(st, p, HomeProvince)
	plain := p.RatePerSec()
	p.Works = map[int]map[string]int{HomeProvince: {"trai": 2, "song": 1}}
	p.Minions = 100
	if p.MinionCap() != MaxMinions+50 {
		t.Fatalf("trại cấp 2 phải +50 lính, got %d", p.MinionCap())
	}
	if p.WorkIncomeMul() != 1.08 {
		t.Fatalf("sòng cấp 1 phải +8%%, got %v", p.WorkIncomeMul())
	}
	if p.RatePerSec() <= plain {
		t.Fatalf("sòng phải tăng thu nhập: %v vs %v", p.RatePerSec(), plain)
	}

	// Mất sạch quận của tỉnh thì công trình ngủ đông (HCM là nhà nên dùng tỉnh khác).
	other := (HomeProvince + 1) % len(Provinces)
	p.Works = map[int]map[string]int{other: {"trai": 2, "song": 1}}
	holdCity(st, p, other)
	withFree := p.RatePerSec()
	for i := other * DistrictSize; i < (other+1)*DistrictSize; i++ {
		delete(p.Owned, i)
	}
	st.recalcLandLocked(p)
	if p.MinionCap() != MaxMinions || p.RatePerSec() >= withFree {
		t.Fatalf("mất tỉnh mà công trình vẫn chạy: cap %d rate %v (%v)",
			p.MinionCap(), p.RatePerSec(), withFree)
	}
}

func TestGoodsFeedMinionsAndDesertion(t *testing.T) {
	st, tok, p := newTestPlayer(t)
	p.Minions = 100
	p.Goods = 0
	p.LastAccrual = time.Now().Add(-time.Minute)
	if _, err := st.State(tok); err != nil {
		t.Fatal(err)
	}
	if p.Minions >= 100 {
		t.Fatalf("hết hàng phải có lính bỏ đi, còn %d", p.Minions)
	}
	if (&Player{}).GoodsUpkeepPerSec() != 0 {
		t.Fatal("không có lính thì không tốn hàng")
	}
}
