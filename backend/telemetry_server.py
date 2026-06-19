#!/usr/bin/env python3
import json
import os
import sys
import time
import urllib.error
import urllib.request
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


APP_ID = os.environ.get("FEISHU_APP_ID", "")
APP_SECRET = os.environ.get("FEISHU_APP_SECRET", "")
BASE_TOKEN = os.environ.get("FEISHU_BASE_TOKEN", "")
TELEMETRY_TABLE_ID = os.environ.get("FEISHU_TELEMETRY_TABLE_ID", "")
HOST = os.environ.get("TELEMETRY_HOST", "0.0.0.0")
PORT = int(os.environ.get("TELEMETRY_PORT", "18080"))
MAX_EVENTS_PER_REQUEST = 50

_tenant_token = ""
_tenant_token_expire_at = 0


def log(*parts):
    print(datetime.now().isoformat(timespec="seconds"), *parts, flush=True)


def require_env():
    missing = [
        name for name, value in {
            "FEISHU_APP_ID": APP_ID,
            "FEISHU_APP_SECRET": APP_SECRET,
            "FEISHU_BASE_TOKEN": BASE_TOKEN,
            "FEISHU_TELEMETRY_TABLE_ID": TELEMETRY_TABLE_ID,
        }.items()
        if not value
    ]
    if missing:
        raise RuntimeError("missing env: " + ", ".join(missing))


def post_json(url, payload, headers=None):
    body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=body,
        headers={
            "Content-Type": "application/json; charset=utf-8",
            **(headers or {}),
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=10) as response:
            return response.status, json.loads(response.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as error:
        text = error.read().decode("utf-8", errors="replace")
        try:
            data = json.loads(text)
        except json.JSONDecodeError:
            data = {"raw": text}
        return error.code, data


def tenant_access_token():
    global _tenant_token, _tenant_token_expire_at
    now = int(time.time())
    if _tenant_token and _tenant_token_expire_at - now > 120:
        return _tenant_token

    status, data = post_json(
        "https://open.feishu.cn/open-apis/auth/v3/tenant_access_token/internal",
        {"app_id": APP_ID, "app_secret": APP_SECRET},
    )
    if status != 200 or data.get("code") != 0:
        raise RuntimeError(f"failed to get tenant token: status={status} body={data}")
    _tenant_token = data["tenant_access_token"]
    _tenant_token_expire_at = now + int(data.get("expire", 7200))
    return _tenant_token


def parse_event_time(value):
    if isinstance(value, (int, float)):
        return int(value)
    if not isinstance(value, str) or not value:
        return int(time.time() * 1000)
    text = value.replace("Z", "+00:00")
    try:
        dt = datetime.fromisoformat(text)
    except ValueError:
        return int(time.time() * 1000)
    if dt.tzinfo is None:
        dt = dt.replace(tzinfo=timezone.utc)
    return int(dt.timestamp() * 1000)


def sanitize_string(value, max_len=500):
    if value is None:
        return ""
    text = str(value)
    return text[:max_len]


def event_to_fields(event):
    properties = event.get("properties")
    if not isinstance(properties, dict):
        properties = {}
    return {
        "事件名称": sanitize_string(event.get("eventName"), 120),
        "事件类型": sanitize_string(event.get("eventType"), 120),
        "发生时间": parse_event_time(event.get("eventTime")),
        "匿名设备ID": sanitize_string(event.get("anonymousDeviceId"), 120),
        "会话ID": sanitize_string(event.get("sessionId"), 120),
        "应用版本": sanitize_string(event.get("appVersion"), 80),
        "系统版本": sanitize_string(event.get("systemVersion"), 160),
        "页面/模块": sanitize_string(event.get("module"), 120),
        "停留时长秒": float(event.get("durationSeconds") or 0),
        "事件属性JSON": json.dumps(properties, ensure_ascii=False, separators=(",", ":"))[:5000],
        "来源": sanitize_string(event.get("source") or "小U待办", 80),
    }


def write_telemetry_events(events):
    records = [{"fields": event_to_fields(event)} for event in events[:MAX_EVENTS_PER_REQUEST]]
    if not records:
        return {"created": 0}

    token = tenant_access_token()
    url = (
        "https://open.feishu.cn/open-apis/bitable/v1/apps/"
        f"{BASE_TOKEN}/tables/{TELEMETRY_TABLE_ID}/records/batch_create"
    )
    status, data = post_json(url, {"records": records}, {"Authorization": f"Bearer {token}"})
    if status != 200 or data.get("code") != 0:
        raise RuntimeError(f"failed to write telemetry: status={status} body={data}")
    return {"created": len(records), "records": data.get("data", {}).get("records", [])}


class Handler(BaseHTTPRequestHandler):
    server_version = "XiaoUTelemetry/1.0"

    def do_GET(self):
        if self.path == "/health":
            self.write_json(200, {"ok": True})
            return
        self.write_json(404, {"error": "not_found"})

    def do_POST(self):
        if self.path not in ("/api/telemetry/batch", "/api/telemetry/event"):
            self.write_json(404, {"error": "not_found"})
            return

        length = int(self.headers.get("Content-Length", "0") or "0")
        if length <= 0 or length > 1024 * 1024:
            self.write_json(400, {"error": "invalid_body_size"})
            return
        try:
            payload = json.loads(self.rfile.read(length).decode("utf-8"))
        except json.JSONDecodeError:
            self.write_json(400, {"error": "invalid_json"})
            return

        events = payload.get("events")
        if events is None and self.path == "/api/telemetry/event":
            events = [payload]
        if not isinstance(events, list):
            self.write_json(400, {"error": "events_must_be_array"})
            return

        try:
            result = write_telemetry_events([event for event in events if isinstance(event, dict)])
        except Exception as exc:
            log("write failed:", exc)
            self.write_json(502, {"error": "write_failed"})
            return
        self.write_json(200, {"ok": True, **result})

    def log_message(self, fmt, *args):
        log(self.address_string(), fmt % args)

    def write_json(self, status, payload):
        body = json.dumps(payload, ensure_ascii=False).encode("utf-8")
        self.send_response(status)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)


def main():
    require_env()
    server = ThreadingHTTPServer((HOST, PORT), Handler)
    log(f"listening on {HOST}:{PORT}")
    server.serve_forever()


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        log("fatal:", exc)
        sys.exit(1)
