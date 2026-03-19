# 🚀 哪吒监控 V1 (Standalone) 极简全自动部署脚本

专为 Woiden、Hax 等**纯 IPv6 且资源受限**的 VPS 打造的哪吒监控 V1 独立版一键部署方案。

本脚本抛弃了官方交互式安装的卡顿与 Docker 的高昂资源占用，通过**硬核纯代码构建**，结合 Caddy h2c 反代与“悬停交互”逻辑，实现真正的保姆级极速闭环部署。

---

## ✨ 核心特性

* [cite_start]🚫 **完全去 Docker 化**：直接部署 Standalone 二进制文件，拒绝 Docker 带来的内存消耗与网络路由污染，保持系统极致纯净 [cite: 1]。
* [cite_start]⚡ **强制 IPv4 满速拉取**：针对 Woiden 等机器访问 GitHub 困难的问题，全程调用 `wget -4` / `curl -s4`，利用你本机已有的 WARP IPv4 网络极速下载面板与探针 。
* [cite_start]🛡️ **Caddy h2c 完美反代**：内置 Caddy 自动配置，将普通网页和 gRPC 流量精准分发至本机 `8008` 端口，完美解决 Cloudflare 环境下 gRPC 频繁中断的痛点 。
* [cite_start]🔒 **127.0.0.1 探针内循环**：本机 Agent 直接绑定 `127.0.0.1:8008` 且关闭 TLS，数据不绕行公网，彻底告别 CF 抽风导致的探针掉线问题 。
* ⏸️ **首创“悬停交互”闭环**：脚本分为上下两段。自动装完面板后会**悬停并打印初始密码**，等你登录后台拿到密钥（Client Secret）并粘贴回终端后，脚本瞬间接力完成探针部署。

---

## ⚠️ 部署前提（非常重要）

在运行此脚本前，请**务必确保**你已经完成了以下准备工作：

1. **VPS 已部署 WARP IPv4**：机器必须具备 IPv4 出站能力（脚本强依赖 IPv4 拉取核心文件）。
2. **域名解析已完成**：在 Cloudflare 中将你的域名（如 `nz.yourdomain.com`）添加 `AAAA` 记录指向本机的 IPv6 地址。
3. **Cloudflare 强关联设置**：
   * 开启小黄云（Proxy 代理）。
   * [cite_start]在左侧菜单 `Network` (网络) 中，确保已开启 **gRPC** 和 **WebSockets** [cite: 5]。
   * [cite_start]在左侧菜单 `SSL/TLS` 中，将加密模式设置为 **Full (Strict)** 或 **Full** [cite: 5]。

---

## 🛠️ 一键安装命令

在具备 WARP IPv4 的纯 IPv6 机器终端中，直接粘贴以下命令回车运行：

```bash
bash <(curl -sL https://raw.githubusercontent.com/tkzjwxx/nezha/main/nezha_v1_install.sh)


运行流程演示
录入域名：脚本启动后，首先会要求你输入已解析的专属域名。

第一段静默部署：脚本将自动清理冗余环境、拉取面板核心、生成守护进程，并安装配置 Caddy 服务器。

⏸️ 脚本悬停与密码提取：

部署到一半时，屏幕会高亮显示从系统日志中抓取的面板后台地址、初始管理员账号及随机密码。

此时脚本会挂起等待。

获取探针密钥：

打开浏览器登录面板后台。

进入【服务器】页面，点击【新增服务器】，随便填写名称（如 Woiden 本机）。

添加成功后，复制生成的 密钥 (Client Secret)。

第二段接力完成：

将密钥粘贴回挂起的 SSH 终端并回车。

脚本瞬间接力，全自动配置并启动本机的环回直连探针。

🎉 享受纯净监控：刷新网页，你的本机探针已满血上线！

📂 核心文件路径备忘
后期如果需要修改配置或排查问题，请参考以下系统路径：

面板目录: /opt/nezha/dashboard


面板配置: /opt/nezha/dashboard/data/config.yaml 

探针目录: /opt/nezha/agent


探针配置: /opt/nezha/agent/config.yml 


Caddy 反代配置: /etc/caddy/Caddyfile 

📝 Disclaimer: 本脚本由社区自动化部署逻辑精简而来，专为极简高效运行环境设计。
