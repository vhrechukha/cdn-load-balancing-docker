$TTL    604800
@       IN      SOA     ns.example.com. root.example.com. (
                         2024092201         ; Serial
                         604800             ; Refresh
                         86400              ; Retry
                         2419200            ; Expire
                         604800 )           ; Negative Cache TTL
;

@       IN      NS      ns.example.com.
ns      IN      A       127.0.0.1
@       IN      A       192.168.1.1
