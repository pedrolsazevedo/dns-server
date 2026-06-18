#!/usr/bin/env bash
# DNS Server Validation Tests
# Expects: docker compose up -d

BIND9="127.0.0.1 -p 5553"
COREDNS="127.0.0.1 -p 1053"
COREDNS_AUTH="127.0.0.1 -p 2053"
PASS=0
FAIL=0

check() {
  local desc="$1" expected="$2" actual="$3"
  if echo "$actual" | grep -q "$expected"; then
    echo "  ✓ $desc"
    ((PASS++))
  else
    echo "  ✗ $desc (expected: $expected, got: $actual)"
    ((FAIL++))
  fi
}

echo "=== DNS Server Tests ==="
echo ""

echo "[1] Container health"
for svc in bind9 coredns coredns-auth; do
  if docker compose ps --status running 2>/dev/null | grep -q "$svc"; then
    check "$svc is running" "$svc" "$svc"
  else
    check "$svc is running" "$svc" "not running"
  fi
done

echo ""
echo "[2] Bind9 — Forward lookups"
ans=$(dig +short @$BIND9 example.com A 2>/dev/null || echo "FAIL")
check "example.com A" "172.20.0.10" "$ans"

ans=$(dig +short @$BIND9 www.example.com A 2>/dev/null || echo "FAIL")
check "www.example.com A" "172.20.0.10" "$ans"

ans=$(dig +short @$BIND9 mail.example.com A 2>/dev/null || echo "FAIL")
check "mail.example.com A" "172.20.0.11" "$ans"

echo ""
echo "[3] Bind9 — MX record"
ans=$(dig +short @$BIND9 example.com MX 2>/dev/null || echo "FAIL")
check "example.com MX" "mail.example.com" "$ans"

echo ""
echo "[4] Bind9 — Reverse lookup"
ans=$(dig +short @$BIND9 -x 172.20.0.10 2>/dev/null || echo "FAIL")
check "172.20.0.10 PTR" "ns1.example.com" "$ans"

echo ""
echo "[5] CoreDNS proxy — Forward to Bind9"
ans=$(dig +short @$COREDNS example.com A 2>/dev/null || echo "FAIL")
check "coredns -> example.com A" "172.20.0.10" "$ans"

ans=$(dig +short @$COREDNS www.example.com A 2>/dev/null || echo "FAIL")
check "coredns -> www.example.com A" "172.20.0.10" "$ans"

echo ""
echo "[6] CoreDNS proxy — Upstream forwarding"
ans=$(dig +short @$COREDNS google.com A 2>/dev/null || echo "FAIL")
if [ -n "$ans" ] && [ "$ans" != "FAIL" ]; then
  check "coredns -> google.com (upstream)" "." "$ans"
else
  check "coredns -> google.com (upstream)" "valid IP" "FAIL"
fi

echo ""
echo "[7] CoreDNS auth — example.com zone"
ans=$(dig +short @$COREDNS_AUTH example.com A 2>/dev/null || echo "FAIL")
check "coredns-auth example.com A" "172.20.0.12" "$ans"

ans=$(dig +short @$COREDNS_AUTH www.example.com A 2>/dev/null || echo "FAIL")
check "coredns-auth www.example.com A" "172.20.0.12" "$ans"

echo ""
echo "[8] CoreDNS auth — service.example.com subdomain zone"
ans=$(dig +short @$COREDNS_AUTH api.service.example.com A 2>/dev/null || echo "FAIL")
check "coredns-auth api.service.example.com A" "172.20.0.20" "$ans"

ans=$(dig +short @$COREDNS_AUTH web.service.example.com A 2>/dev/null || echo "FAIL")
check "coredns-auth web.service.example.com A" "172.20.0.21" "$ans"

ans=$(dig +short @$COREDNS_AUTH db.service.example.com A 2>/dev/null || echo "FAIL")
check "coredns-auth db.service.example.com A" "172.20.0.22" "$ans"

ans=$(dig +short @$COREDNS_AUTH cache.service.example.com A 2>/dev/null || echo "FAIL")
check "coredns-auth cache.service.example.com A" "172.20.0.23" "$ans"

echo ""
echo "[9] CoreDNS auth — SRV records"
ans=$(dig +short @$COREDNS_AUTH _http._tcp.service.example.com SRV 2>/dev/null || echo "FAIL")
check "coredns-auth _http._tcp SRV" "web.service.example.com" "$ans"

echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
