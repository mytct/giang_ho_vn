package main

import (
	"encoding/json"
	"log"
	"net/http"
	"os"
	"time"
)

func writeJSON(w http.ResponseWriter, code int, v any) {
	w.Header().Set("Content-Type", "application/json; charset=utf-8")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

func fail(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}

func readToken(r *http.Request) string {
	if t := r.URL.Query().Get("token"); t != "" {
		return t
	}
	return r.Header.Get("X-Token")
}

func withCORS(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		w.Header().Set("Access-Control-Allow-Origin", "*")
		w.Header().Set("Access-Control-Allow-Headers", "Content-Type, X-Token")
		w.Header().Set("Access-Control-Allow-Methods", "GET, POST, OPTIONS")
		if r.Method == http.MethodOptions {
			w.WriteHeader(http.StatusNoContent)
			return
		}
		next.ServeHTTP(w, r)
	})
}

func withLog(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		next.ServeHTTP(w, r)
		log.Printf("%s %s %v", r.Method, r.URL.Path, time.Since(start).Round(time.Millisecond))
	})
}

func registerRoutes(mux *http.ServeMux, st *Store) {
	devEnabled := os.Getenv("GIANGHO_DEV") != "0"

	mux.HandleFunc("POST /api/dev/seed", func(w http.ResponseWriter, r *http.Request) {
		if !devEnabled {
			fail(w, 404, "dev tools đã tắt")
			return
		}
		writeJSON(w, 200, map[string]any{"ok": true, "players": st.SeedDemo()})
	})

	mux.HandleFunc("POST /api/dev/login", func(w http.ResponseWriter, r *http.Request) {
		if !devEnabled {
			fail(w, 404, "dev tools đã tắt")
			return
		}
		var body struct {
			Name string `json:"name"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		tok, err := st.DevLogin(body.Name)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"token": tok})
	})

	mux.HandleFunc("POST /api/dev/max", func(w http.ResponseWriter, r *http.Request) {
		if !devEnabled {
			fail(w, 404, "dev tools đã tắt")
			return
		}
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.MaxAccount(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, state)
	})

	mux.HandleFunc("POST /api/dev/unlimited", func(w http.ResponseWriter, r *http.Request) {
		if !devEnabled {
			fail(w, 404, "dev tools đã tắt")
			return
		}
		var body struct {
			Token string `json:"token"`
			On    bool   `json:"on"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.SetDevUnlimited(body.Token, body.On)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, state)
	})

	mux.HandleFunc("POST /api/dev/reset-territories", func(w http.ResponseWriter, r *http.Request) {
		if !devEnabled {
			fail(w, 404, "dev tools đã tắt")
			return
		}
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.ResetTerritories(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, state)
	})

	mux.HandleFunc("POST /api/dev/grant", func(w http.ResponseWriter, r *http.Request) {
		if !devEnabled {
			fail(w, 404, "dev tools đã tắt")
			return
		}
		var body struct {
			Token string `json:"token"`
			Count int    `json:"count"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.GrantTerritories(body.Token, body.Count)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, state)
	})

	mux.HandleFunc("GET /api/health", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]string{"ok": "đang chạy"})
	})

	mux.HandleFunc("POST /api/login", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Name string `json:"name"`
		}
		if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
			fail(w, 400, "dữ liệu không hợp lệ")
			return
		}
		_, tok, err := st.Login(body.Name)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		state, err := st.State(tok)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"token": tok, "state": state})
	})

	mux.HandleFunc("GET /api/state", func(w http.ResponseWriter, r *http.Request) {
		state, err := st.State(readToken(r))
		if err != nil {
			fail(w, 401, err.Error())
			return
		}
		writeJSON(w, 200, state)
	})

	mux.HandleFunc("POST /api/upgrade", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token    string `json:"token"`
			Business string `json:"business"`
			District int    `json:"district"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.UpgradeBusiness(body.Token, body.Business, body.District)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/recruit", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.Recruit(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/minion/recruit", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			Count int    `json:"count"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.RecruitMinions(body.Token, body.Count)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/minion/gear", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
			Count int    `json:"count"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.BuyMinionGear(body.Token, body.ID, body.Count)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/minion/heal", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			Count int    `json:"count"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.HealMinions(body.Token, body.Count)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/weapon", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.UpgradeWeapon(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("GET /api/map", func(w http.ResponseWriter, r *http.Request) {
		territories, state, err := st.Map(readToken(r))
		if err != nil {
			fail(w, 401, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"territories": territories, "state": state})
	})

	mux.HandleFunc("POST /api/attack", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token     string `json:"token"`
			Territory int    `json:"territory"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		result, state, err := st.Attack(body.Token, body.Territory)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"result": result, "state": state})
	})

	mux.HandleFunc("POST /api/mission/claim", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.ClaimMission(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/level/spend", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			Stat  string `json:"stat"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.SpendPoint(body.Token, body.Stat)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/daily/claim", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.ClaimDaily(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/territory/upgrade", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token     string `json:"token"`
			Territory int    `json:"territory"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.UpgradeTerritory(body.Token, body.Territory)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/city/build", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token    string `json:"token"`
			District int    `json:"district"`
			Work     string `json:"work"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.BuildWork(body.Token, body.District, body.Work)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("GET /api/campaign", func(w http.ResponseWriter, r *http.Request) {
		chapters, current, err := st.Campaign(readToken(r))
		if err != nil {
			fail(w, 401, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"chapters": chapters, "current": current})
	})

	mux.HandleFunc("POST /api/campaign/fight", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			Index int    `json:"index"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		res, state, err := st.FightChapter(body.Token, body.Index)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"result": res, "state": state})
	})

	mux.HandleFunc("POST /api/prestige", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.Prestige(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/crew/assign", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token     string `json:"token"`
			Territory int    `json:"territory"`
			Crew      int    `json:"crew"`
			Minions   int    `json:"minions"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.AssignGuard(body.Token, body.Territory, body.Crew, body.Minions)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/crew/formation", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			Kind  string `json:"kind"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.SetFormation(body.Token, body.Kind)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/heat/bribe", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.BribeHeat(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("GET /api/bounties", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]any{"rows": st.Bounties(readToken(r))})
	})

	mux.HandleFunc("POST /api/bounty", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token  string `json:"token"`
			ID     string `json:"id"`
			Amount int64  `json:"amount"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.SetBounty(body.Token, body.ID, body.Amount)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("GET /api/inbox", func(w http.ResponseWriter, r *http.Request) {
		msgs, unread, err := st.Inbox(readToken(r))
		if err != nil {
			fail(w, 401, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"messages": msgs, "unread": unread})
	})

	mux.HandleFunc("POST /api/inbox/battle", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		rec, err := st.DefenseBattle(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"record": rec})
	})

	mux.HandleFunc("POST /api/gang/upgrade", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			Kind  string `json:"kind"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.UpgradeGang(body.Token, body.Kind)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/business/racket", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.RaiseRacket(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/general/recruit", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.RecruitGeneral(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/general/train", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.TrainGeneral(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("GET /api/gang/chat", func(w http.ResponseWriter, r *http.Request) {
		chat, err := st.GangChat(readToken(r))
		if err != nil {
			fail(w, 401, err.Error())
			return
		}
		writeJSON(w, 200, chat)
	})

	mux.HandleFunc("POST /api/gang/chat", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			Text  string `json:"text"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		chat, err := st.SendGangChat(body.Token, body.Text)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, chat)
	})

	mux.HandleFunc("POST /api/gang/promote", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token    string `json:"token"`
			TargetID string `json:"targetId"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		chat, err := st.PromoteMember(body.Token, body.TargetID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, chat)
	})

	mux.HandleFunc("POST /api/gang/payout", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token  string `json:"token"`
			Amount int64  `json:"amount"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		chat, err := st.PayoutTreasury(body.Token, body.Amount)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, chat)
	})

	mux.HandleFunc("POST /api/inbox/read", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.ReadInbox(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("GET /api/contracts", func(w http.ResponseWriter, r *http.Request) {
		offers, active, err := st.Contracts(readToken(r))
		if err != nil {
			fail(w, 401, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"offers": offers, "active": active})
	})

	mux.HandleFunc("POST /api/contract/accept", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.AcceptContract(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/contract/claim", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.ClaimContract(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/casino", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token  string `json:"token"`
			Choice string `json:"choice"`
			Bet    int64  `json:"bet"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		res, state, err := st.CasinoPlay(body.Token, body.Choice, body.Bet)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"result": res, "state": state})
	})

	mux.HandleFunc("GET /api/boss", func(w http.ResponseWriter, r *http.Request) {
		boss, state, err := st.BossInfo(readToken(r))
		if err != nil {
			fail(w, 401, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"boss": boss, "state": state})
	})

	mux.HandleFunc("POST /api/boss/hit", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		res, state, err := st.BossHit(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"result": res, "state": state})
	})

	mux.HandleFunc("POST /api/shop/item", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.BuyItem(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("GET /api/diplomacy", func(w http.ResponseWriter, r *http.Request) {
		gangs, edges, err := st.Diplomacy(readToken(r))
		if err != nil {
			fail(w, 401, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"gangs": gangs, "edges": edges})
	})

	mux.HandleFunc("GET /api/gangs", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]any{"gangs": st.Gangs(readToken(r))})
	})

	mux.HandleFunc("POST /api/gang/create", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			Name  string `json:"name"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.CreateGang(body.Token, body.Name)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/gang/join", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.JoinGang(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/gang/leave", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.LeaveGang(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/gang/ally", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.AllyGang(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/gang/unally", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.UnallyGang(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/gang/tribute", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.DemandTribute(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/gang/break-tribute", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.BreakTribute(body.Token)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("POST /api/gang/war", func(w http.ResponseWriter, r *http.Request) {
		var body struct {
			Token string `json:"token"`
			ID    string `json:"id"`
		}
		_ = json.NewDecoder(r.Body).Decode(&body)
		state, err := st.DeclareWar(body.Token, body.ID)
		if err != nil {
			fail(w, 400, err.Error())
			return
		}
		writeJSON(w, 200, map[string]any{"state": state})
	})

	mux.HandleFunc("GET /api/ranking", func(w http.ResponseWriter, r *http.Request) {
		writeJSON(w, 200, map[string]any{"rows": st.Ranking(readToken(r))})
	})
}
