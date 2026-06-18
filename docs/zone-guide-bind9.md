# Bind9 Zone Configuration Guide

How to add domains, subdomains, and records using Bind9.

**Service:** `bind9` | **Port:** 5553 | **IP:** 172.20.0.10

---

## Adding a New Domain

Example: adding `mylab.local`

### 1. Create the zone file

Create `data/zones/db.mylab.local`:

```
$TTL 86400
@   IN  SOA ns1.mylab.local. admin.mylab.local. (
        2024010101  ; Serial (YYYYMMDDNN)
        3600        ; Refresh
        900         ; Retry
        604800      ; Expire
        86400 )     ; Negative Cache TTL

    IN  NS  ns1.mylab.local.

ns1     IN  A   172.20.0.10
@       IN  A   172.20.0.10
www     IN  A   172.20.0.10
```

### 2. Register the zone

Add to `data/config/named.conf.local`:

```
zone "mylab.local" {
  type master;
  file "/var/lib/bind/db.mylab.local";
};
```

### 3. Restart and test

```bash
docker compose restart bind9
dig @127.0.0.1 -p 5553 mylab.local A
```

---

## Adding Subdomains

Subdomains are A/CNAME records in the parent zone file.

### A records

Add to `data/zones/db.example.com`:

```
api     IN  A   172.20.0.10
blog    IN  A   172.20.0.10
dev     IN  A   172.20.0.11
```

### CNAME records (aliases)

```
shop    IN  CNAME   www.example.com.
docs    IN  CNAME   www.example.com.
```

> CNAMEs must point to an FQDN with a trailing dot.

### Wildcard subdomain

```
*       IN  A   172.20.0.10
```

### Delegated subdomain zone

To delegate `service.example.com` as its own zone:

1. Add NS record in parent zone (`data/zones/db.example.com`):
```
service IN  NS  ns1.example.com.
```

2. Create `data/zones/db.service.example.com`:
```
$TTL 86400
@   IN  SOA ns1.example.com. admin.example.com. (
        2024010101 3600 900 604800 86400 )
    IN  NS  ns1.example.com.

api     IN  A   172.20.0.20
web     IN  A   172.20.0.21
```

3. Register in `data/config/named.conf.local`:
```
zone "service.example.com" {
  type master;
  file "/var/lib/bind/db.service.example.com";
};
```

### After adding records

1. Increment the SOA serial (e.g., `2024010101` → `2024010102`)
2. Restart: `docker compose restart bind9`
3. Validate: `docker exec bind9 named-checkzone example.com /var/lib/bind/db.example.com`

---

## Reverse Zones (PTR)

For IP → name lookups:

### 1. Create zone file

For `10.0.0.0/24`, create `data/zones/db.10.0.0`:

```
$TTL 86400
@   IN  SOA ns1.mylab.local. admin.mylab.local. (
        2024010101 3600 900 604800 86400 )
    IN  NS  ns1.mylab.local.

1   IN  PTR gateway.mylab.local.
10  IN  PTR server.mylab.local.
```

### 2. Register

```
zone "0.0.10.in-addr.arpa" {
  type master;
  file "/var/lib/bind/db.10.0.0";
};
```

### 3. Test

```bash
dig @127.0.0.1 -p 5553 -x 10.0.0.10
```

---

## Testing

```bash
# Forward lookups
dig @127.0.0.1 -p 5553 example.com A
dig @127.0.0.1 -p 5553 +short www.example.com

# Record types
dig @127.0.0.1 -p 5553 example.com MX
dig @127.0.0.1 -p 5553 example.com NS
dig @127.0.0.1 -p 5553 example.com TXT

# Reverse
dig @127.0.0.1 -p 5553 -x 172.20.0.10

# Zone transfer
dig @127.0.0.1 -p 5553 example.com AXFR

# Validate zone syntax
docker exec bind9 named-checkzone example.com /var/lib/bind/db.example.com
```

---

## Troubleshooting

| Symptom | Fix |
|---------|-----|
| `SERVFAIL` | Check zone syntax: `docker exec bind9 named-checkzone <zone> <file>` |
| `REFUSED` | Verify ACL in `named.conf.options` includes client IP |
| Changes not visible | Increment SOA serial and restart bind9 |
| Container won't start | Check logs: `docker compose logs bind9` |

---

## Record Types Reference

| Type  | Purpose | Example |
|-------|---------|---------|
| A     | Name → IPv4 | `www IN A 172.20.0.10` |
| AAAA  | Name → IPv6 | `www IN AAAA ::1` |
| CNAME | Alias | `shop IN CNAME www.example.com.` |
| MX    | Mail server | `@ IN MX 10 mail.example.com.` |
| TXT   | Text/SPF | `@ IN TXT "v=spf1 mx -all"` |
| NS    | Nameserver | `@ IN NS ns1.example.com.` |
| PTR   | IP → Name | `10 IN PTR ns1.example.com.` |
| SRV   | Service locator | `_http._tcp IN SRV 0 5 80 www.example.com.` |
