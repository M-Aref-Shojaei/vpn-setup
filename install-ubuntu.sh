#!/usr/bin/env bash
# install-ubuntu.sh — one-shot installer for mihomo + clashtui with Iran bypass
# Works on Ubuntu 20.04+ (amd64 or arm64). Run as root or with sudo.
#
# Usage:
#   sudo bash install-ubuntu.sh <subscription-url>
#
# What it installs:
#   /usr/local/bin/mihomo        — the routing core (TUN + Iran bypass)
#   /usr/local/bin/clashtui      — the TUI client
#   /etc/clashtui/               — config, profile, rule sets
#   systemd service clashtui_mihomo — runs the core at boot with TUN
set -euo pipefail

SUB_URL="${1:?usage: sudo bash install-ubuntu.sh <subscription-url>}"
ARCH=$(dpkg --print-architecture 2>/dev/null || uname -m)
case "$ARCH" in
  amd64|x86_64) ARCH=amd64 ;;
  arm64|aarch64) ARCH=arm64 ;;
  *) echo "unsupported arch: $ARCH"; exit 1 ;;
esac

echo ">> [1/6] downloading mihomo (linux-$ARCH)..."
MH_VER=$(curl -fsSL https://api.github.com/repos/MetaCubeX/mihomo/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
curl -fSL "https://github.com/MetaCubeX/mihomo/releases/download/${MH_VER}/mihomo-linux-${ARCH}-${MH_VER}.gz" -o /tmp/mihomo.gz
gunzip -f /tmp/mihomo.gz && chmod +x /tmp/mihomo
install -m 755 /tmp/mihomo /usr/local/bin/mihomo
# TUN without sudo — Linux privilege model allows this
setcap cap_net_admin,cap_net_bind_service,cap_net_raw=+ep /usr/local/bin/mihomo

echo ">> [2/6] downloading clashtui (linux-$ARCH)..."
CT_VER=$(curl -fsSL https://api.github.com/repos/JohanChane/clashtui/releases/latest | grep -o '"tag_name": *"[^"]*"' | cut -d'"' -f4)
curl -fSL "https://github.com/JohanChane/clashtui/releases/download/${CT_VER}/clashtui-linux-${ARCH}-${CT_VER}.gz" -o /tmp/clashtui.gz
gunzip -f /tmp/clashtui.gz && chmod +x /tmp/clashtui
install -m 755 /tmp/clashtui /usr/local/bin/clashtui

echo ">> [3/6] creating config layout..."
mkdir -p /etc/clashtui/mihomo/config/ruleset /etc/clashtui/mihomo/profiles /etc/clashtui/mihomo/templates

echo ">> [4/6] downloading Iran rule sets (Chocolate4U/Iran-clash-rules)..."
for f in ir.mrs ircidr.mrs iranserver.mrs; do
  curl -fSL "https://github.com/Chocolate4U/Iran-clash-rules/releases/latest/download/$f" \
    -o "/etc/clashtui/mihomo/config/ruleset/$f"
done

echo ">> [5/6] writing configs..."
# ---- clashtui main config ----
cat > /etc/clashtui/config.yaml <<'EOF'
mihomo:
  core:
    config_dir: /etc/clashtui/mihomo/config
    bin_path: /usr/local/bin/mihomo
    config_path: /etc/clashtui/mihomo/config/config.yaml
  core_service:
    service_name: clashtui_mihomo
    is_user: false
timeout: null
extra:
  edit_cmd: vim "%s"
  open_dir_cmd: ls "%s"
EOF

# ---- core override: TUN + DNS + Iran bypass (same as the Mac setup) ----
cat > /etc/clashtui/mihomo/core_override_config.yaml <<'EOF'
external-controller: 127.0.0.1:9090
mixed-port: 7890
allow-lan: false
mode: rule
log-level: info

tun:
  enable: true
  stack: mixed
  auto-route: true
  auto-detect-interface: true
  dns-hijack:
    - any:53

dns:
  enable: true
  listen: 127.0.0.1:1053
  enhanced-mode: fake-ip
  fake-ip-range: 198.18.0.1/16
  nameserver:
    - https://1.1.1.1/dns-query
    - https://dns.google/dns-query

rule-providers:
  ir-domains:
    type: http
    behavior: domain
    format: mrs
    url: https://github.com/Chocolate4U/Iran-clash-rules/releases/latest/download/ir.mrs
    path: /etc/clashtui/mihomo/config/ruleset/ir.mrs
    interval: 86400
  ir-cidr:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Chocolate4U/Iran-clash-rules/releases/latest/download/ircidr.mrs
    path: /etc/clashtui/mihomo/config/ruleset/ircidr.mrs
    interval: 86400
  iran-server:
    type: http
    behavior: ipcidr
    format: mrs
    url: https://github.com/Chocolate4U/Iran-clash-rules/releases/latest/download/iranserver.mrs
    path: /etc/clashtui/mihomo/config/ruleset/iranserver.mrs
    interval: 86400

rules:
  - RULE-SET,ir-domains,DIRECT
  - DOMAIN-SUFFIX,ir,DIRECT
  - RULE-SET,iran-server,DIRECT,no-resolve
  - RULE-SET,ir-cidr,DIRECT,no-resolve
  - IP-CIDR,10.0.0.0/8,DIRECT,no-resolve
  - IP-CIDR,172.16.0.0/12,DIRECT,no-resolve
  - IP-CIDR,192.168.0.0/16,DIRECT,no-resolve
  - IP-CIDR,127.0.0.0/8,DIRECT,no-resolve
  - MATCH,PROXY
EOF

# ---- clashtui profile database: registers the subscription ----
cat > /etc/clashtui/clashtui.db <<EOF
core_type: mihomo
mihomo:
  cur_profile: karun
  profiles:
    karun:
      dtype: !Url ${SUB_URL}
      no_pp: false
singbox:
  profiles: {}
EOF

# ---- systemd unit: core runs at boot, TUN-capable via setcap ----
cat > /etc/systemd/system/clashtui_mihomo.service <<'EOF'
[Unit]
Description=mihomo routing core (clashtui-managed)
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
ExecStart=/usr/local/bin/mihomo -d /etc/clashtui/mihomo/config -f /etc/clashtui/mihomo/config/config.yaml
ExecReload=/bin/kill -HUP $MAINPID
Restart=on-failure
RestartSec=5
LimitNOFILE=1048576
# TUN caps granted via setcap; still need ambient caps for systemd context
CapabilityBoundingSet=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW
AmbientCapabilities=CAP_NET_NET_BIND_SERVICE CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW

[Install]
WantedBy=multi-user.target
EOF
# fix the typo-proof way: rewrite the AmbientCapabilities line cleanly
sed -i 's/^AmbientCapabilities=.*/AmbientCapabilities=CAP_NET_ADMIN CAP_NET_BIND_SERVICE CAP_NET_RAW/' \
  /etc/systemd/system/clashtui_mihomo.service

echo ">> [6/6] fetching subscription and validating..."
# fetch the subscription as clash yaml (the provider serves it with clash UA)
curl -fsSL -A "clash.meta" "$SUB_URL" -o /etc/clashtui/mihomo/profiles/karun.yaml \
  || echo "!! subscription fetch failed — check URL; profile file left empty"

systemctl daemon-reload

# merge profile + override into the live config using clashtui itself
clashtui --config-dir=/etc/clashtui profile update --name karun 2>&1 | grep -v "^$" || true

# validate with mihomo before enabling the service
if mihomo -t -d /etc/clashtui/mihomo/config -f /etc/clashtui/mihomo/config/config.yaml >/dev/null 2>&1; then
  echo "   config valid ✔"
else
  echo "   !! config invalid — inspect: mihomo -t -d /etc/clashtui/mihomo/config -f /etc/clashtui/mihomo/config/config.yaml"
  exit 1
fi

systemctl enable --now clashtui_mihomo
sleep 2
systemctl --no-pager -l status clashtui_mihomo | head -6 || true

echo ""
echo "=== DONE ==="
echo "core:  systemctl status clashtui_mihomo"
echo "tui:   clashtui   (run as any user; it talks to the core via 127.0.0.1:9090)"
echo "logs:  journalctl -u clashtui_mihomo -f"
echo ""
echo "verify: curl --max-time 10 https://api.ipify.org        # should be the VPN IP"
echo "        curl --max-time 10 -o /dev/null -w '%{http_code}\\n' https://digikala.com  # direct, 200/30x"
