$TTL 86400
@   IN  SOA ns1.example.com. admin.example.com. (
        2026061801  ; Serial
        3600        ; Refresh
        900         ; Retry
        604800      ; Expire
        86400 )     ; Negative Cache TTL

    IN  NS  ns1.example.com.

ns1     IN  A   172.20.0.10
@       IN  A   172.20.0.10
www     IN  A   172.20.0.10
mail    IN  A   172.20.0.11
@       IN  MX  10 mail.example.com.
