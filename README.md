# 🚀 Nezha V1 Standalone Deployer / 哪吒监控 V1 独立版一键部署

[English](#english) | [简体中文](#chinese)

---

<h2 id="english">🇺🇸 English</h2>

A highly optimized, fully automated deployment script for **Nezha Monitoring V1 (Standalone)**, specifically designed for pure IPv6 VPS (like Woiden, Hax) that have WARP IPv4 installed.

### ⚙️ Core Architecture
* **Dashboard**: Pure binary deployment (No Docker required).
* **Reverse Proxy**: Caddy (Auto HTTPS + h2c gRPC proxy for Cloudflare).
* **Agent**: Local loopback direct connection (`127.0.0.1:8008`) for the host machine.

### ✨ Highlights
* 🧹 **Aggressive Port Clearing**: Automatically kills conflicting processes on ports 80 and 443 to ensure Caddy starts successfully.
* 🤖 **Smart Secret Extraction**: Just paste the entire `curl` installation command provided by the dashboard, and the script will cleverly extract the pure `NZ_CLIENT_SECRET`.
* ⚡ **Zero Setup**: Uses the default `admin/admin` credentials. Fully interactive script pauses at the exact right moment for you to configure the dashboard.

### ⚠️ Prerequisites
Before running the script, make sure you have configured your domain in **Cloudflare**:
1. Added an `AAAA` record pointing to your VPS's IPv6 address.
2. Enabled the **Orange Cloud (Proxy)**.
3. Enabled **gRPC** and **WebSockets** in the Network tab.
4. Set SSL/TLS encryption mode to **Full (Strict)** or **Full**.

### 🚀 Quick Install
Run the following command as `root`:

```bash
bash <(curl -sL [https://raw.githubusercontent.com/tkzjwxx/nezha-v1-ipv6/main/install.sh](https://raw.githubusercontent.com/tkzjwxx/nezha-v1-ipv6/main/install.sh))
```

---

<h2 id="chinese">🇨🇳 简体中文</h2>

专为纯 IPv6 VPS（如 Woiden、Hax，需已挂载 WARP IPv4）打造的**哪吒监控 V1（纯净独立版）全自动部署引擎**。

抛弃臃肿的 Docker，采用最纯粹的二进制底层运行，将性能压榨到极致！

### ⚙️ 核心架构
* **面板端 (Dashboard)**：官方最新 V1 二进制文件，底层 Systemd 守护。
* **反代引擎 (Proxy)**：Caddy (完美适配 Cloudflare 的 gRPC h2c 转发，全自动 SSL)。
* **探针端 (Agent)**：本机内网穿透直连 (`127.0.0.1:8008`)，无惧外网波动。

### ✨ 独家优化特性
* 🧹 **霸道清场**：自动拔除 80/443 端口的“钉子户”（如旧版 Nginx/Apache），护航 Caddy 完美启动。
* 🤖 **智能防呆提取**：在录入本机探针密钥时，无论你粘贴的是纯字母密钥，还是官方那一长串 `curl` 安装命令，脚本都能瞬间精准提取出 `NZ_CLIENT_SECRET` 的值。
* ⚡ **丝滑交互**：部署完面板后自动挂起等待，直观展示默认账号密码（`admin`），等你拿到密钥后一键接力部署探针。

### ⚠️ 运行前必看：CF 设置
请务必提前在 **Cloudflare** 完成以下设置：
1. 域名已添加 `AAAA` 记录并指向本机 IPv6。
2. 开启**小黄云 (Proxy)**。
3. 在 CF 的“网络 (Network)”设置中，开启 **gRPC** 和 **WebSockets**。
4. 将 SSL/TLS 加密模式设置为 **Full (Strict)** 或 **Full**。

### 🚀 一键部署指令
请使用 `root` 权限登录终端，直接粘贴以下命令回车：

```bash
bash <(curl -sL [https://raw.githubusercontent.com/tkzjwxx/nezha-v1-ipv6/main/install.sh](https://raw.githubusercontent.com/tkzjwxx/nezha-v1-ipv6/main/install.sh))
```
*(💡 提示：跟着屏幕上极具赛博朋克风的彩色中文提示走，两分钟内即可完成部署并点亮本机探针！)*
