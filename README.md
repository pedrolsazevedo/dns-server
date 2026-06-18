# DNS Server Lab

Bind9 (authoritative + recursive) and CoreDNS (forwarding proxy) for studying DNS.

## Architecture
```
                ┌────────────┐
  client ──53──►│  CoreDNS   │──forward──► Bind9 (local zones)
                │  :1053     │──forward──► 1.1.1.1 (upstream)
                └────────────┘
                ┌────────────┐
  client ──53──►│   Bind9    │ authoritative for example.com
                │  :53       │ recursive resolver for trusted ACL
                └────────────┘
```

## Quick Start

```bash
# Option A: Build local image (supports amd64 + arm64)
docker compose up -d --build

# Option B: Use official ISC image (amd64 only)
BIND9_IMAGE=internetsystemsconsortium/bind9:9.20 docker compose up -d --no-build

# Validate
bash tests/validate.sh
```

## Multi-Arch Build (for arm64/Raspberry Pi)

```bash
docker buildx bake --set '*.platform=linux/amd64' --load   # local
docker buildx bake --push                                    # registry
```

## Services

| Service | Host Port | Container IP | Role |
|---------|-----------|--------------|------|
| Bind9   | 5553      | 172.20.0.10  | Authoritative + recursive DNS |
| CoreDNS | 1053      | 172.20.0.11  | Forwarding proxy with cache |
| CoreDNS Auth | 2053 | 172.20.0.12  | Authoritative DNS (alternative to Bind9) |

## Query Examples

```bash
# Direct to Bind9
dig @127.0.0.1 -p 5553 example.com A
dig @127.0.0.1 -p 5553 -x 172.20.0.10

# Via CoreDNS
dig @127.0.0.1 -p 1053 example.com A
dig @127.0.0.1 -p 1053 google.com A
```

## Documentation

- [docs/plan.md](docs/plan.md) — Project plan and architecture
- [docs/zone-guide-bind9.md](docs/zone-guide-bind9.md) — Bind9 zone configuration guide
- [docs/zone-guide-coredns.md](docs/zone-guide-coredns.md) — CoreDNS authoritative zone guide
- [docs/multi-arch-build.md](docs/multi-arch-build.md) — Docker Bake multi-arch setup

## Folder Structure

```
data/
├── config/          # Bind9 configuration (mounted read-only)
│   ├── named.conf
│   ├── named.conf.options
│   └── named.conf.local
├── coredns/         # CoreDNS Corefile
├── coredns-auth/    # CoreDNS authoritative config + zone files
│   ├── Corefile
│   ├── db.example.com
│   └── db.service.example.com
└── zones/           # Zone files (mounted read-only)
    ├── db.example.com
    └── db.172.20.0
docs/                # Documentation
tests/
└── validate.sh      # Validation script (18 checks)
Dockerfile           # Multi-arch bind9 image
docker-bake.hcl      # Buildx bake definition
```

## Zone: example.com

| Record | Type | Value |
|--------|------|-------|
| @      | A    | 172.20.0.10 |
| www    | A    | 172.20.0.10 |
| mail   | A    | 172.20.0.11 |
| ns1    | A    | 172.20.0.10 |
| @      | MX   | 10 mail.example.com. |
| 10     | PTR  | ns1.example.com. (reverse) |
