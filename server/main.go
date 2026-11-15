package main

import (
	"log"
	"net/http"
	"os"
)

func main() {
	st := NewStore()
	mux := http.NewServeMux()
	registerRoutes(mux, st)

	addr := os.Getenv("ADDR")
	if addr == "" {
		addr = ":8089"
	}
	log.Printf("giang ho server listening on %s", addr)
	if err := http.ListenAndServe(addr, withLog(withCORS(mux))); err != nil {
		log.Fatal(err)
	}
}
