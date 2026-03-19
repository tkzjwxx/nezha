#!/bin/bash
# ====================================================================
# 哪吒监控 V1 (Standalone) 极简全自动部署脚本 - Woiden/Hax 专供版 V5
# 核心架构：纯二进制面板 + Caddy(h2c反代) + 本机127直连探针
# 独家优化：智能提取一键安装命令中的密钥 + 默认admin密码提示
# ====================================================================

RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${CYAN}=================================================================${NC}"
echo -e "${GREEN}      🚀 哪吒监控 V1 (独立版) 极简全自动部署引擎启动！ V5${NC}"
echo -e "${CYAN}=================================================================${NC}\n"

# --------------------------------------------------------
# 🚧 第一关：环境强提醒与域名录入
# --------------------------------------------------------
echo -e "${YELLOW}⚠️ 【准备工作确认清单】请务必确认以下操作已在 Cloudflare 完成：${NC}"
echo -e "  1. 你的域名已添加 AAAA 记录，并指向本机的 IPv6 地址。"
echo -e "  2. 域名的【小黄云 (Proxy)】已开启。"
echo -e "  3. CF 的 Network (网络) 设置中，已开启 ${GREEN}gRPC${NC} 和 ${GREEN}WebSockets${NC}。"
echo -e "  4. SSL/TLS 加密模式已设置为 ${GREEN}Full (Strict)${NC} 或 ${GREEN}Full${NC}。"
echo -e "${CYAN}-----------------------------------------------------------------${NC}"
read -p "👉 如果上述设置已全部完成，请按 [回车键] 继续，否则请按 Ctrl+C 退出配置..." 

echo -e "\n${GREEN}▶ 开始配置 Caddy 反代与面板域名前置${NC}"
while true; do
    read -p "👉 请输入你已经解析到本机的专属域名 (如 nz.989269.xyz): " RAW_DOMAIN
    MY_DOMAIN=$(echo "$RAW_DOMAIN" | tr -d '\r' | tr -d ' ')
    if [ -n "$MY_DOMAIN" ]; then
        echo -e "✅ 已锁定纯净面板域名: ${YELLOW}$MY_DOMAIN${NC}\n"
        break
    else
        echo -e "${RED}❌ 域名不能为空，请重新输入！${NC}"
    fi
done

# --------------------------------------------------------
# 🚀 第二关：强制清理历史残留、杀 80 端口与依赖更新
# --------------------------------------------------------
echo -e "${CYAN}📦 正在更新系统依赖并强制拔除 80 端口占用...${NC}"
apt update && apt install wget curl unzip jq psmisc -y >/dev/null 2>&1

systemctl stop docker nezha-dashboard nezha-agent caddy apache2 nginx 2>/dev/null
apt purge docker.io containerd runc apache2 apache2-utils apache2.2-bin apache2-common nginx nginx-common -y >/dev/null 2>&1
fuser -k -9 80/tcp >/dev/null 2>&1

rm -rf /opt/nezha /etc/systemd/system/nezha-*
systemctl daemon-reload

# --------------------------------------------------------
# 📦 第三关：硬核手搓面板端
# --------------------------------------------------------
echo -e "${CYAN}⬇️ 正在通过 WARP IPv4 满速拉取哪吒 V1 核心二进制文件...${NC}"
mkdir -p /opt/nezha/dashboard
wget -4 -qO /tmp/nezha-dashboard.zip https://github.com/nezhahq/nezha/releases/latest/download/dashboard-linux-amd64.zip

if [ ! -s /tmp/nezha-dashboard.zip ]; then
    echo -e "${RED}❌ 面板下载失败，请检查你的 WARP IPv4 是否连通 Github！${NC}"
    exit 1
fi
unzip -qo /tmp/nezha-dashboard.zip -d /opt/nezha/dashboard

BINARY=$(find /opt/nezha/dashboard -type f -name "dashboard*" | head -n 1)
if [ -n "$BINARY" ]; then
    mv "$BINARY" /opt/nezha/dashboard/dashboard
fi
chmod +x /opt/nezha/dashboard/dashboard

echo -e "${CYAN}⚙️ 正在生成 Dashboard 系统守护进程...${NC}"
cat > /etc/systemd/system/nezha-dashboard.service << EOF
[Unit]
Description=Nezha Dashboard
After=network.target

[Service]
Type=simple
WorkingDirectory=/opt/nezha/dashboard
ExecStart=/opt/nezha/dashboard/dashboard
Restart=always

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable --now nezha-dashboard >/dev/null 2>&1

echo -e "${YELLOW}⏳ 等待全新面板初始化并生成底层配置 (超时30秒)...${NC}"
WAIT_TIME=0
while [ ! -f /opt/nezha/dashboard/data/config.yaml ]; do
    sleep 2
    ((WAIT_TIME+=2))
    if [ $WAIT_TIME -ge 30 ]; then
        echo -e "${RED}❌ 面板初始化超时！请执行 journalctl -u nezha-dashboard 排查。${NC}"
        exit 1
    fi
done

sed -i 's/tls: true/tls: false/g' /opt/nezha/dashboard/data/config.yaml
systemctl restart nezha-dashboard

# --------------------------------------------------------
# 🛡️ 第四关：部署 Caddy 并注入 h2c 反代配置
# --------------------------------------------------------
echo -e "${CYAN}🛡️ 正在安装 Caddy (Cloudflare gRPC 完美搭档)...${NC}"
apt install -y debian-keyring debian-archive-keyring apt-transport-https >/dev/null 2>&1
curl -4 -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/gpg.key' | gpg --dearmor -o /usr/share/keyrings/caddy-stable-archive-keyring.gpg --yes >/dev/null 2>&1
curl -4 -1sLf 'https://dl.cloudsmith.io/public/caddy/stable/debian.deb.txt' | tee /etc/apt/sources.list.d/caddy-stable.list >/dev/null
apt update >/dev/null 2>&1 && apt install caddy -y >/dev/null 2>&1

echo -e "${CYAN}⚙️ 正在写入纯净版 Caddyfile 路由规则...${NC}"
cat > /etc/caddy/Caddyfile << EOF
$MY_DOMAIN {
    @grpc {
        header Content-Type application/grpc*
    }
    handle @grpc {
        reverse_proxy h2c://127.0.0.1:8008
    }
    handle {
        reverse_proxy 127.0.0.1:8008
    }
}
EOF
systemctl restart caddy

if ! systemctl is-active --quiet caddy; then
    echo -e "${RED}❌ Caddy 反代引擎启动失败！可能是 443 端口冲突导致，请检查！${NC}"
    journalctl -u caddy -n 20 --no-pager
    exit 1
fi

# --------------------------------------------------------
# ⏸️ 第五关：悬停交互 (直接提示默认密码 -> 智能索要探针密钥)
# --------------------------------------------------------
sleep 2
echo -e "\n${CYAN}=================================================================${NC}"
echo -e "${GREEN}🎉 面板底层架构与 Caddy 反代已全部部署并启动成功！${NC}"
echo -e "${CYAN}=================================================================${NC}"
echo -e "🌐 ${YELLOW}后台地址:${NC} https://$MY_DOMAIN/"
echo -e "👤 ${YELLOW}默认账号:${NC} ${GREEN}admin${NC}"
echo -e "🔑 ${YELLOW}默认密码:${NC} ${GREEN}admin${NC}"

echo -e "\n${RED}==================== 🛑 脚本挂起等待中 🛑 ====================${NC}"
echo -e "1. 请打开浏览器，访问上方后台地址并登录 (进去后记得修改密码)。"
echo -e "2. 在后台【设置】页面，将【未接入探针的连接地址】改为: ${YELLOW}$MY_DOMAIN:443${NC} (用于外部机器)"
echo -e "3. 进入【服务器】页面，点击【新增服务器】(如命名 Woiden本机)。"
echo -e "4. 复制面板给你的 ${YELLOW}一键安装命令${NC} 或纯 ${YELLOW}密钥(Secret)${NC}。"
echo -e "${RED}==============================================================${NC}\n"

while true; do
    read -p "👉 请粘贴纯密钥 或 完整的安装命令，然后回车: " RAW_SECRET
    
    # 智能防呆：如果用户粘贴了完整的安装命令，正则提取出 NZ_CLIENT_SECRET 的值
    EXTRACTED_SECRET=$(echo "$RAW_SECRET" | grep -oE "NZ_CLIENT_SECRET=[^ ]+" | cut -d= -f2)
    
    if [ -n "$EXTRACTED_SECRET" ]; then
        CLIENT_SECRET="$EXTRACTED_SECRET"
    else
        # 否则当作用户输入的是纯文本密钥，直接去除空格回车
        CLIENT_SECRET=$(echo "$RAW_SECRET" | tr -d '\r' | tr -d ' ')
    fi

    if [ -n "$CLIENT_SECRET" ]; then
        echo -e "✅ 智能提取成功！当前锁定本机密钥: ${YELLOW}$CLIENT_SECRET${NC}"
        echo -e "▶ 继续自动部署本机探针...\n"
        break
    else
        echo -e "${RED}❌ 未检测到有效密钥，请重新粘贴！${NC}"
    fi
done

# --------------------------------------------------------
# 📡 第六关：全自动部署本机 Agent
# --------------------------------------------------------
echo -e "${CYAN}📦 正在通过 WARP IPv4 满速拉取探针二进制文件...${NC}"
mkdir -p /opt/nezha/agent
wget -4 -qO /tmp/nezha-agent.zip https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.zip
unzip -qo /tmp/nezha-agent.zip -d /opt/nezha/agent

AGENT_BIN=$(find /opt/nezha/agent -type f -name "nezha-agent*" | head -n 1)
if [ -n "$AGENT_BIN" ]; then
    mv "$AGENT_BIN" /opt/nezha/agent/nezha-agent
fi
chmod +x /opt/nezha/agent/nezha-agent 2>/dev/null

echo -e "${CYAN}⚙️ 正在生成本机环回探针配置...${NC}"
cat > /opt/nezha/agent/config.yml << EOF
server: 127.0.0.1:8008
client_secret: $CLIENT_SECRET
tls: false
report_delay: 3
skip_connection_count: false
skip_procs_count: false
EOF

cat > /etc/systemd/system/nezha-agent.service << EOF
[Unit]
Description=Nezha Agent
After=syslog.target
StartLimitIntervalSec=0

[Service]
Type=simple
User=root
WorkingDirectory=/opt/nezha/agent
ExecStart=/opt/nezha/agent/nezha-agent -c /opt/nezha/agent/config.yml
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

systemctl daemon-reload && systemctl enable --now nezha-agent >/dev/null 2>&1

# --------------------------------------------------------
# 🧹 第七关：完美扫尾
# --------------------------------------------------------
rm -f /tmp/nezha-dashboard.zip /tmp/nezha-agent.zip
apt clean >/dev/null 2>&1

echo -e "\n${CYAN}=================================================================${NC}"
echo -e "${GREEN}🎉 恭喜！哪吒 V1 独立版 + 本机探针已完美部署闭环！${NC}"
echo -e "去网页后台看看吧，你的本机探针现在应该已经是在线状态了！"
echo -e "${CYAN}=================================================================${NC}"
