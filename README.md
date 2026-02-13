# OpenClaw on Heroku

Deploy [OpenClaw](https://github.com/openclaw/openclaw) to Heroku via Container Registry，使用 [coollabsio/openclaw](https://github.com/coollabsio/openclaw) 預建 Docker image。

## Architecture

```
Internet
  ↓ HTTPS (Heroku Router)
  ↓
┌─────────────────────────────────────┐
│  Heroku Dyno (Container Stack)     │
│                                     │
│  coollabsio/openclaw:latest        │
│  ┌──────────┐    ┌──────────────┐  │
│  │  nginx    │───→│  openclaw    │  │
│  │  :$PORT   │    │  gateway     │  │
│  │  (auth)   │    │  :18789      │  │
│  └──────────┘    └──────────────┘  │
│                                     │
│  /data/ (ephemeral ⚠️)             │
└─────────────────────────────────────┘
```

---

## 前置需求

| 工具 | 安裝方式 | 用途 |
|------|---------|------|
| [Heroku CLI](https://devcenter.heroku.com/articles/heroku-cli) | `curl https://cli-assets.heroku.com/install.sh \| sh` | 管理 Heroku app |
| [Docker](https://docs.docker.com/get-docker/) | 依作業系統安裝 | 建置容器映像檔 |

另外你需要：
- **Heroku 帳號**（含信用卡驗證，可使用免費 credits）
- **OpenRouter API Key**（免費取得）

---

## 部署步驟

### Step 1: 取得 OpenRouter API Key

1. 前往 [openrouter.ai](https://openrouter.ai) 並註冊帳號
2. 登入後到 [openrouter.ai/keys](https://openrouter.ai/keys)
3. 點擊 **Create Key**，取得格式為 `sk-or-v1-...` 的 API Key

> 💡 免費帳號每天可使用免費模型 50 次。充值 $10 後提升至 1000 次/天。

### Step 2: Clone 專案

```bash
git clone <this-repo-url>
cd openclaw
```

### Step 3: 設定環境變數

```bash
cp .env.example .env
vim .env
```

| 變數 | 說明 | 範例 |
|------|------|------|
| `OPENROUTER_API_KEY` | 你的 OpenRouter API Key | `sk-or-v1-abc123...` |
| `AUTH_PASSWORD` | 登入密碼 | `MyStr0ngP@ssw0rd!` |

其餘設定可保持預設：
- `OPENCLAW_PRIMARY_MODEL` — 預設使用 Claude Sonnet
- `OPENCLAW_GATEWAY_TOKEN` — 會自動產生
- `AUTH_USERNAME` — 預設為 `admin`

### Step 4: 登入 Heroku

```bash
heroku login
```

### Step 5: 部署

```bash
bash deploy.sh
```

這個 script 會自動：
1. 建立 Heroku app（名稱為 `openclaw-<你的使用者名稱>`）
2. 設定所有環境變數
3. 登入 Heroku Container Registry
4. Build 並推送 Docker image
5. Release 並啟動 dyno

### Step 6: 升級 Dyno（避免休眠）

```bash
heroku ps:scale web=1:standard-1x -a <your-app-name>
```

| Dyno Type | 價格 | 休眠? | 建議 |
|-----------|------|-------|------|
| Basic | $7/mo | ⚠️ 30min 無流量後休眠 | ❌ Agent 需要持續運行 |
| Standard-1X | $25/mo | ✅ 不休眠 | ✅ 生產環境最低要求 |
| Standard-2X | $50/mo | ✅ 不休眠 | 重負載使用 |

**有 $312 credits + Standard-1X → 約 12 個月免費。**

### Step 7: 開啟 & 登入

1. 開啟 `https://<app-name>.herokuapp.com`
2. 帳號 `admin` / 你在 Step 3 設定的密碼

---

## Channel 設定（選配）

### Telegram（最簡單）
1. 在 Telegram 找 [@BotFather](https://t.me/BotFather)，`/newbot` 建立機器人
2. 取得 Bot Token（格式：`123456:ABC-DEF...`）
3. ```bash
   heroku config:set -a <app> \
     TELEGRAM_BOT_TOKEN="你的-bot-token" \
     TELEGRAM_DM_POLICY="pairing"
   ```
4. 對 bot 發訊息，透過 `heroku logs --tail -a <app>` 核准配對

### Discord
1. 在 [Discord Developer Portal](https://discord.com/developers) 建立 bot
2. 啟用 MESSAGE CONTENT INTENT
3. `heroku config:set DISCORD_BOT_TOKEN=<token> -a <app>`

### Slack
1. 建立 Slack app 並啟用 Socket Mode
2. `heroku config:set SLACK_BOT_TOKEN=xoxb-... SLACK_APP_TOKEN=xapp-... -a <app>`

---

## ⚠️ Ephemeral Filesystem

Heroku 的檔案系統是**暫時性的**，以下情況會清空 `/data/`：
- Dyno 重啟（每日循環）
- 重新部署
- Scale 事件

### 持久化方案

**方案 A：接受暫時狀態（最簡單）**
- OpenClaw 重啟後重新 onboard
- 對話記錄會重置
- 適合測試 / 輕度使用

**方案 B：S3 同步（生產環境建議）**
```bash
# 在 entrypoint wrapper 中：
aws s3 sync s3://your-bucket/openclaw-state/ /data/.openclaw/ --quiet
# ... start openclaw ...
# 透過 cron 或 SIGTERM trap 定期同步
```
需設定：`heroku config:set AWS_ACCESS_KEY_ID=... AWS_SECRET_ACCESS_KEY=...`

---

## 常用指令

```bash
heroku logs --tail -a <app>       # 即時 logs
heroku config -a <app>            # 查看環境變數
heroku run bash -a <app>          # 進入 dyno shell
heroku ps -a <app>                # 查看 dyno 狀態
heroku ps:restart -a <app>        # 重啟

# 更換模型
heroku config:set -a <app> OPENCLAW_PRIMARY_MODEL="meta-llama/llama-4-maverick:free"
```

---

## 故障排除

| 問題 | 解法 |
|------|------|
| App 無法啟動 | `heroku logs --tail -a <app>`，檢查 API Key 是否正確 |
| 對話記錄消失 | 正常現象（ephemeral filesystem），參考上方 S3 方案 |
| 免費模型回應品質不佳 | 更換模型：`heroku config:set OPENCLAW_PRIMARY_MODEL="deepseek/deepseek-r1:free" -a <app>` |

---

## Migration Path（離開 Heroku）

Docker image 可直接搬到任何 VPS：

```bash
docker run -d \
  --name openclaw \
  -p 8080:8080 \
  -e OPENROUTER_API_KEY=sk-or-... \
  -e AUTH_PASSWORD=changeme \
  -v openclaw-data:/data \
  coollabsio/openclaw:latest
```

或使用 `docker-compose.yml` 搭配 browser sidecar。

## Heroku 限制

- **No browser sidecar** — 單一 container，CDP browser 無法運行
- **No sandbox** — Docker-in-Docker 不支援
- **Ephemeral filesystem** — 需 S3 才能持久化
- **512MB RAM (Standard-1X)** — 通常夠用，用 `heroku logs` 監控
