#!/bin/bash
# ====================================================================
# 哪吒监控 V1 (Standalone) 极简全自动部署脚本 - Woiden/Hax 专供版
# 核心架构：纯二进制面板 + Caddy(h2c反代) + 本机127直连探针
# 运行前提：VPS 已具备纯净的 WARP IPv4 出口能力
# ====================================================================

# 颜色定义
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
CYAN='\033[1;36m'
NC='\033[0m'

clear
echo -e "${CYAN}=================================================================${NC}"
echo -e "${GREEN}      🚀 哪吒监控 V1 (独立版) 极简全自动部署引擎启动！${NC}"
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
    read -p "👉 请输入你已经解析到本机的专属域名 (如 nz.989269.xyz): " MY_DOMAIN
    if [ -n "$MY_DOMAIN" ]; then
        echo -e "✅ 已锁定面板域名: ${YELLOW}$MY_DOMAIN${NC}\n"
        break
    else
        echo -e "${RED}❌ 域名不能为空，请重新输入！${NC}"
    fi
done

# --------------------------------------------------------
# 🚀 第二关：基础环境清理与依赖更新
# --------------------------------------------------------
echo -e "${CYAN}📦 正在更新系统依赖并清理冗余环境...${NC}"
apt update && apt install wget curl unzip jq -y >/dev/null 2>&1
systemctl stop docker 2>/dev/null
apt purge docker.io containerd runc -y 2>/dev/null
apt autoremove -y >/dev/null 2>&1

# --------------------------------------------------------
# 📦 第三关：硬核手搓面板端 (彻底剥离官方脚本)
# --------------------------------------------------------
echo -e "${CYAN}⬇️ 正在通过 WARP IPv4 满速拉取哪吒 V1 核心二进制文件...${NC}"
mkdir -p /opt/nezha/dashboard
# 强制走 IPv4 获取最新版本号并下载，防 GitHub 阻断
wget -4 -qO /tmp/nezha-dashboard.zip https://github.com/nezhahq/nezha/releases/latest/download/dashboard-linux-amd64.zip
unzip -qo /tmp/nezha-dashboard.zip -d /opt/nezha/dashboard
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

echo -e "${YELLOW}⏳ 等待面板初始化并生成底层配置...${NC}"
# 等待 config.yaml 生成
while [ ! -f /opt/nezha/dashboard/data/config.yaml ]; do sleep 1; done

# 强制将面板自带 TLS 关闭，交由 Caddy 处理
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

echo -e "${CYAN}⚙️ 正在写入 Caddyfile 路由规则...${NC}"
cat > /etc/caddy/Caddyfile << EOF
$MY_DOMAIN {
    # 针对 Agent 的 gRPC 流量识别与转发
    @grpc {
        header Content-Type application/grpc*
    }
    handle @grpc {
        reverse_proxy h2c://127.0.0.1:8008
    }
    # 针对普通网页的转发
    handle {
        reverse_proxy 127.0.0.1:8008
    }
}
EOF
systemctl restart caddy

# --------------------------------------------------------
# ⏸️ 第五关：悬停交互 (获取账号密码 -> 索要探针密钥)
# --------------------------------------------------------
sleep 3 # 给系统一点缓冲时间输出日志
echo -e "\n${CYAN}=================================================================${NC}"
echo -e "${GREEN}🎉 面板底层架构与 Caddy 反代已全部部署并启动成功！${NC}"
echo -e "${CYAN}=================================================================${NC}"
echo -e "🌐 ${YELLOW}你的后台地址:${NC} https://$MY_DOMAIN/"
echo -e "👇 ${YELLOW}后台初始登录凭证 (从系统底层日志提取):${NC}"

# 从日志中提取用户名和密码
journalctl -u nezha-dashboard --no-pager -n 100 | grep -E "用户名|密码|username|password|User|Password" | tail -n 4 | while read line; do
    echo -e "   ${GREEN}$line${NC}"
done

echo -e "\n${RED}==================== 🛑 脚本挂起等待中 🛑 ====================${NC}"
echo -e "1. 请现在打开浏览器，访问上方后台地址并登录。"
echo -e "2. 进入【服务器】或【节点】管理页面，点击【新增服务器】。"
echo -e "3. 随便填个名字(如 Woiden本机)，添加后复制对应的 ${YELLOW}密钥 (Client Secret)${NC}。"
echo -e "${RED}==============================================================${NC}\n"

while true; do
    read -p "👉 请在此处粘贴你刚刚复制的 Agent 密钥并回车: " CLIENT_SECRET
    if [ -n "$CLIENT_SECRET" ]; then
        echo -e "✅ 已捕获密钥，继续自动部署本机探针...\n"
        break
    else
        echo -e "${RED}❌ 密钥不能为空！${NC}"
    fi
done

# --------------------------------------------------------
# 📡 第六关：全自动部署本机 Agent (127.0.0.1直连)
# --------------------------------------------------------
echo -e "${CYAN}📦 正在通过 WARP IPv4 满速拉取探针二进制文件...${NC}"
rm -rf /opt/nezha/agent && mkdir -p /opt/nezha/agent
wget -4 -qO /tmp/nezha-agent.zip https://github.com/nezhahq/agent/releases/latest/download/nezha-agent_linux_amd64.zip
unzip -qo /tmp/nezha-agent.zip -d /opt/nezha/agent
chmod +x /opt/nezha/agent/nezha-agent

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
