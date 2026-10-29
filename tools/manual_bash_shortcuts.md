[[ <- Назад ]](/README.md)

- Запущенные Node.js и их версии

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/roles/server_info/files/nodejs_manual.sh -o /tmp/nodejs_manual.sh && sudo sh /tmp/nodejs_manual.sh
```

- Срез DNS

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/roles/server_info/files/dns_manual.sh -o /tmp/dns_manual.sh && sudo bash /tmp/dns_manual.sh
```

- Срез IPv6

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/roles/server_info/files/ipv6_manual.sh -o /tmp/ipv6_manual.sh && sudo sh /tmp/ipv6_manual.sh
```

- DHCP-клиент

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/roles/server_info/files/dhcp_manual.sh -o /tmp/dhcp_manual.sh && sudo sh /tmp/dhcp_manual.sh
```

- Файрволы

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/roles/server_info/files/firewall_manual.sh -o /tmp/firewall_manual.sh && sudo sh /tmp/firewall_manual.sh
```

- ОС

```bash
curl -fsSL https://raw.githubusercontent.com/shumilovsergey/semaphore/refs/heads/main/roles/server_info/files/os_manual.sh -o /tmp/os_manual.sh && sudo sh /tmp/os_manual.sh
```
