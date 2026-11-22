package main

import (
	"log"
	"net/http"
	"os"
	"strconv"
	"time"
)

func main() {
	st := NewStore()
	mux := http.NewServeMux()
	registerRoutes(mux, st)

	// Snapshot ra file để tài khoản/băng/đất sống qua restart.
	savePath := os.Getenv("GIANGHO_SAVE")
	if savePath == "" {
		savePath = "giangho_save.json"
	}
	st.Load(savePath)

	bots := 0
	if v := os.Getenv("GIANGHO_BOTS"); v != "" {
		bots, _ = strconv.Atoi(v)
	} else if os.Getenv("GIANGHO_DEV") != "0" {
		bots = 6
	}
	st.StartBots(bots)

	go func() {
		for {
			time.Sleep(20 * time.Second)
			st.Save(savePath)
		}
	}()

	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8089"
	}
	log.Printf("giang ho server listening on %s", addr)
	if err := http.ListenAndServe(addr, withLog(withCORS(mux))); err != nil {
		log.Fatal(err)
	}
}
