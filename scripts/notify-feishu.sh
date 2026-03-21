#!/bin/bash
# 发送飞书通知
# 用法: ./scripts/notify-feishu.sh "<title>" "<body>"

TITLE="${1:-Issue 处理完成}"
BODY="${2:-新的 Issue 已处理完毕}"

APP_ID="cli_a922e5ddaeb8dbc3"
APP_SECRET="049enpZONlrAnf91BDMLMczIG63RaTGn"
USER_OPEN_ID="ou_716a580f47ba7c01cde66bef39fcaf11"

python3 << 'PYEOF'
import urllib.request, urllib.parse, json, sys

app_id = "cli_a922e5ddaeb8dbc3"
app_secret = "049enpZONlrAnf91BDMLMczIG63RaTGn"
user_id = "ou_716a580f47ba7c01cde66bef39fcaf11"
title = sys.argv[1] if len(sys.argv) > 1 else "Issue 处理完成"
body = sys.argv[2] if len(sys.argv) > 2 else "新的 Issue 已处理完毕"

# Get tenant access token
req = urllib.request.Request(
    "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
    data=json.dumps({"app_id": app_id, "app_secret": app_secret}).encode(),
    headers={"Content-Type": "application/json"},
    method="POST"
)
with urllib.request.urlopen(req) as resp:
    token_data = json.loads(resp.read())

token = token_data.get("tenant_access_token", "")
if not token:
    print(f"❌ 获取 token 失败: {token_data}")
    sys.exit(1)

# Send message
msg_req = urllib.request.Request(
    "https://open.feishu.cn/open-apis/im/v1/messages?receive_id_type=open_id",
    data=json.dumps({
        "receive_id": user_id,
        "msg_type": "text",
        "content": json.dumps({"text": f"🔔 {title}\n\n{body}"})
    }).encode(),
    headers={
        "Authorization": f"Bearer {token}",
        "Content-Type": "application/json"
    },
    method="POST"
)
with urllib.request.urlopen(msg_req) as resp:
    result = json.loads(resp.read())

code = result.get("code", -1)
if code == 0:
    print("✅ 飞书通知已发送")
else:
    print(f"❌ 发送失败: {result}")
PYEOF
