$TTL 86400
@   IN  SOA ns1.example.com. admin.example.com. (
        2026061801  ; Serial
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
