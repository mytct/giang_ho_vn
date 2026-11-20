"""Fake 20 băng để test bản đồ: mỗi bot lập băng, rồi chém ngẫu nhiên địa bàn.

Chạy server local trước (cd server && go run .), rồi:
    python3 tools/fake_gangs.py [--gangs 20] [--rounds 40] [--base http://localhost:8089]
"""

import argparse
import json
import random
import time
import urllib.error
import urllib.request


def call(base, path, body=None):
    data = json.dumps(body or {}).encode()
    req = urllib.request.Request(
        base + path, data=data, headers={"Content-Type": "application/json"}, method="POST"
    )
    try:
        with urllib.request.urlopen(req, timeout=10) as resp:
            return json.loads(resp.read() or b"{}")
    except urllib.error.HTTPError as e:
        return {"error": e.read().decode(errors="replace"), "status": e.code}


def get(base, path):
    with urllib.request.urlopen(base + path, timeout=10) as resp:
        return json.loads(resp.read())


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--gangs", type=int, default=20)
    ap.add_argument("--rounds", type=int, default=40)
    ap.add_argument("--base", default="http://localhost:8089")
    ap.add_argument("--delay", type=float, default=0.05)
    args = ap.parse_args()

    if "ok" not in get(args.base, "/api/health"):
        raise SystemExit("server chưa chạy")

    bots = []
    for i in range(args.gangs):
        name = f"Bot{i + 1:02d}"
        res = call(args.base, "/api/login", {"name": name})
        tok = res.get("token")
        if not tok:
            print("login lỗi", name, res)
            continue
        call(args.base, "/api/dev/unlimited", {"token": tok, "on": True})
        call(args.base, "/api/dev/max", {"token": tok})
        g = call(args.base, "/api/gang/create", {"token": tok, "name": f"Băng {name}"})
        if "error" in g:
            print("lập băng lỗi", name, g["error"][:120])
        bots.append({"name": name, "token": tok})
    print(f"{len(bots)} bot sẵn sàng")

    total_territories = len(get(args.base, f"/api/map?token={bots[0]['token']}")["territories"])
    won = lost = failed = 0
    for r in range(args.rounds):
        for bot in random.sample(bots, len(bots)):
            tid = random.randrange(total_territories)
            res = call(args.base, "/api/attack", {"token": bot["token"], "territory": tid})
            if "error" in res:
                failed += 1
            elif res.get("result", {}).get("win"):
                won += 1
            else:
                lost += 1
            time.sleep(args.delay)
        print(f"vòng {r + 1}/{args.rounds}: thắng {won}, thua {lost}, lỗi {failed}")


if __name__ == "__main__":
    main()
