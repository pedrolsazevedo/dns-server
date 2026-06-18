# CoreDNS Zone Configuration Guide

How to configure CoreDNS as an authoritative DNS server with the `file` plugin, including subdomain zone delegation.

**Service:** `coredns-auth` | **Port:** 2053 | **IP:** 172.20.0.12

---

## How It Works

CoreDNS uses the `file` plugin to serve authoritative zone data from standard BIND-format zone files. Each server block in the Corefile defines what zone it's authoritative for.

```
example.com {
  file /etc/coredns/db.example.com
  log
}
```

Key differences from Bind9:
- Configuration is in `Corefile` (not `named.conf`)
- No zone registration needed — just a server block per zone
- Same zone file format (BIND-compatible)
- Plugins are composable (add `cache`, `log`, `errors` as needed)

---

## Adding a New Domain

Example: adding `mylab.local`

### 1. Create the zone file

Create `data/coredns-auth/db.mylab.local`:

```
$TTL 86400
@   IN  SOA ns1.mylab.local. admin.mylab.local. (
        2024010101  ; Serial
        3600        ; Refresh
        900         ; Retry
        604800      ; Expire
        86400 )     ; Negative Cache TTL

    IN  NS  ns1.mylab.local.

ns1     IN  A   172.20.0.12
@       IN  A   172.20.0.12
www     IN  A   172.20.0.12
```

### 2. Add server block to Corefile

Add to `data/coredns-auth/Corefile`:

```
mylab.local {
  file /etc/coredns/db.mylab.local
  log
}
```

### 3. Restart and test

```bash
docker compose restart coredns-auth
dig @127.0.0.1 -p 2053 mylab.local A
```

---

## Subdomain Zones

CoreDNS handles subdomain zones by defining a **more specific** server block. The most specific match wins (like `service.example.com` takes priority over `example.com`).

### Example: `service.example.com` zone

This is how the lab's subdomain zone is configured:

**Corefile** (`data/coredns-auth/Corefile`):

```
service.example.com {
  file /etc/coredns/db.service.example.com
  log
}

example.com {
  file /etc/coredns/db.example.com
  log
}

. {
  forward . 1.1.1.1 1.0.0.1
  cache 30
  log
}
```

> **Order matters:** put the subdomain block *before* the parent domain.

**Zone file** (`data/coredns-auth/db.service.example.com`):

```
$TTL 86400
@   IN  SOA ns1.example.com. admin.example.com. (
        2024010101  ; Serial
        3600        ; Refresh
        900         ; Retry
        604800      ; Expire
        86400 )     ; Negative Cache TTL

    IN  NS  ns1.example.com.

; App services
api     IN  A   172.20.0.20
web     IN  A   172.20.0.21
db      IN  A   172.20.0.22
cache   IN  A   172.20.0.23
@       IN  A   172.20.0.20

; SRV records for service discovery
_http._tcp   IN  SRV  0 5 80  web.service.example.com.
_https._tcp  IN  SRV  0 5 443 web.service.example.com.
_redis._tcp  IN  SRV  0 5 6379 cache.service.example.com.
```

### Test subdomain records

```bash
dig @127.0.0.1 -p 2053 api.service.example.com A
dig @127.0.0.1 -p 2053 web.service.example.com A
dig @127.0.0.1 -p 2053 _http._tcp.service.example.com SRV
```

---

## Adding Subdomains (Simple)

For subdomains within an existing zone (no delegation), just add records to the zone file:

```
api     IN  A   172.20.0.20
blog    IN  A   172.20.0.20
shop    IN  CNAME  www.example.com.
*       IN  A   172.20.0.12
```

Increment the serial and restart:

```bash
docker compose restart coredns-auth
```

---

## Useful Plugins

| Plugin | Purpose | Example |
|--------|---------|---------|
| `file` | Serve zone from file | `file /etc/coredns/db.example.com` |
| `log` | Log queries to stdout | `log` |
| `errors` | Log errors | `errors` |
| `cache` | Cache responses | `cache 30` |
| `forward` | Proxy to upstream | `forward . 1.1.1.1` |
| `reload` | Auto-reload zone files | `reload 10s` |

### Auto-reload zone changes

Add `reload` to avoid manual restarts:

```
example.com {
  file /etc/coredns/db.example.com
  reload 10s
  log
}
```

CoreDNS checks the SOA serial every 10s and reloads if it changes.

---

## Testing

```bash
# Forward lookups
dig @127.0.0.1 -p 2053 example.com A
dig @127.0.0.1 -p 2053 +short www.example.com

# Subdomain zone
dig @127.0.0.1 -p 2053 api.service.example.com A
dig @127.0.0.1 -p 2053 +short web.service.example.com

# SRV records
dig @127.0.0.1 -p 2053 _http._tcp.service.example.com SRV

# Upstream forwarding (catch-all block)
dig @127.0.0.1 -p 2053 google.com A
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `SERVFAIL` | Check zone file format (SOA, NS records required) |
| `NXDOMAIN` for subdomain | Verify subdomain block is before parent in Corefile |
| Changes not visible | Increment SOA serial; add `reload` plugin |
| Container won't start | Check logs: `docker compose logs coredns-auth` |
| Plugin error | Verify plugin order — `file` must come before `forward` |

---

## Comparison: CoreDNS vs Bind9

| Aspect | Bind9 | CoreDNS |
|--------|-------|---------|
| Config format | `named.conf` + zone files | `Corefile` + zone files |
| Zone registration | `named.conf.local` | Server block in Corefile |
| Hot reload | `rndc reload` | `reload` plugin (auto) |
| Plugins/modules | Compiled-in | Plugin chain (composable) |
| Reverse zones | Full PTR support | `file` plugin supports PTR |
| DNSSEC | Full support | `dnssec` plugin |
| Footprint | ~50MB image | ~17MB image |
| Language | C | Go |
