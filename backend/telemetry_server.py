#!/usr/bin/env python3
import json
import os
import sys
import tempfile
import threading
import time
import urllib.error
import urllib.request
from datetime import datetime, timedelta, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from zoneinfo import ZoneInfo


APP_ID = os.environ.get("FEISHU_APP_ID", "")
APP_SECRET = os.environ.get("FEISHU_APP_SECRET", "")
BASE_TOKEN = os.environ.get("FEISHU_BASE_TOKEN", "")
TELEMETRY_TABLE_ID = os.environ.get("FEISHU_TELEMETRY_TABLE_ID", "")
FEEDBACK_TABLE_ID = os.environ.get("FEISHU_FEEDBACK_TABLE_ID", "")
HOST = os.environ.get("TELEMETRY_HOST", "0.0.0.0")
PORT = int(os.environ.get("TELEMETRY_PORT", "18080"))
LOCAL_TZ = ZoneInfo(os.environ.get("TELEMETRY_TIMEZONE", "Asia/Shanghai"))
AGGREGATE_PATH = os.environ.get("TELEMETRY_AGGREGATE_PATH", "/var/lib/xiaou-telemetry/aggregate-state.json")
AGGREGATE_RETENTION_DAYS = int(os.environ.get("TELEMETRY_AGGREGATE_RETENTION_DAYS", "120"))
AGGREGATE_MAX_BYTES = int(os.environ.get("TELEMETRY_AGGREGATE_MAX_BYTES", str(50 * 1024 * 1024)))
MAX_EVENTS_PER_REQUEST = 50
ALLOWED_EVENT_TYPES = {
    "应用启动",
    "应用退出",
    "页面访问",
    "功能点击",
    "反馈提交",
    "错误",
    "心跳",
    "测试事件",
}
CORE_EVENT_NAMES = {
    "app_start",
    "app_exit",
    "session_heartbeat",
    "feedback_submitted",
    "note_ai_summary_clicked",
    "desktop_ai_summary_clicked",
    "calendar_sync",
    "ai_summary_week",
    "ai_summary_month",
    "note_window_layer_changed",
}

EVENT_NAME_LABELS = {
    "app_start": "应用启动",
    "app_exit": "应用退出",
    "session_heartbeat": "使用心跳",
    "feedback_submitted": "用户反馈",
    "note_ai_summary_clicked": "主窗口AI总结",
    "desktop_ai_summary_clicked": "桌面待办AI总结",
    "calendar_sync": "同步到日历",
    "ai_summary_week": "总结本周",
    "ai_summary_month": "总结本月",
    "note_window_layer_changed": "桌面待办层级切换",
}

MODULE_LABELS = {
    "app": "应用",
    "feedback": "用户反馈",
    "summary": "AI总结",
    "calendar": "日历同步",
    "desktop_note": "桌面待办",
    "main_window": "主窗口",
    "settings": "设置",
}

_tenant_token = ""
_tenant_token_expire_at = 0
_feedback_table_id = ""
_aggregate_lock = threading.Lock()


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


def get_json(url, headers=None):
    request = urllib.request.Request(
        url,
        headers={
            "Content-Type": "application/json; charset=utf-8",
            **(headers or {}),
        },
        method="GET",
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


def feishu_headers():
    return {"Authorization": f"Bearer {tenant_access_token()}"}


def feedback_table_id():
    global _feedback_table_id
    if _feedback_table_id:
        return _feedback_table_id
    if FEEDBACK_TABLE_ID:
        _feedback_table_id = FEEDBACK_TABLE_ID
        return _feedback_table_id

    url = (
        "https://open.feishu.cn/open-apis/bitable/v1/apps/"
        f"{BASE_TOKEN}/tables?page_size=100"
    )
    status, data = get_json(url, feishu_headers())
    if status != 200 or data.get("code") != 0:
        raise RuntimeError(f"failed to list tables: status={status} body={data}")
    for item in data.get("data", {}).get("items", []):
        if item.get("name") == "用户反馈管理":
            _feedback_table_id = item.get("table_id", "")
            return _feedback_table_id
    return ""


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
        dt = dt.replace(tzinfo=LOCAL_TZ)
    return int(dt.timestamp() * 1000)


def local_day_key(ms):
    return datetime.fromtimestamp(ms / 1000, LOCAL_TZ).date().isoformat()


def sanitize_string(value, max_len=500):
    if value is None:
        return ""
    text = str(value)
    return text[:max_len]


def load_aggregate_state():
    if not AGGREGATE_PATH:
        return {"version": 1, "knownDevices": {}, "days": {}}
    try:
        with open(AGGREGATE_PATH, "r", encoding="utf-8") as file:
            state = json.load(file)
    except FileNotFoundError:
        return {"version": 1, "knownDevices": {}, "days": {}}
    except (OSError, json.JSONDecodeError) as exc:
        log("aggregate load failed, starting fresh:", exc)
        return {"version": 1, "knownDevices": {}, "days": {}}
    if not isinstance(state, dict):
        return {"version": 1, "knownDevices": {}, "days": {}}
    state.setdefault("version", 1)
    if not isinstance(state.get("knownDevices"), dict):
        state["knownDevices"] = {}
    if not isinstance(state.get("days"), dict):
        state["days"] = {}
    return state


def prune_aggregate_state(state):
    days = state.setdefault("days", {})
    if AGGREGATE_RETENTION_DAYS <= 0:
        days.clear()
        return
    cutoff = (datetime.now(LOCAL_TZ).date() - timedelta(days=AGGREGATE_RETENTION_DAYS - 1)).isoformat()
    for day in list(days.keys()):
        if day < cutoff:
            days.pop(day, None)


def save_aggregate_state(state):
    if not AGGREGATE_PATH:
        return
    prune_aggregate_state(state)
    payload = json.dumps(state, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
    while len(payload) > AGGREGATE_MAX_BYTES and state.get("days"):
        oldest_day = min(state["days"])
        state["days"].pop(oldest_day, None)
        payload = json.dumps(state, ensure_ascii=False, separators=(",", ":"), sort_keys=True).encode("utf-8")
    if len(payload) > AGGREGATE_MAX_BYTES:
        raise RuntimeError(f"aggregate state too large: {len(payload)} bytes")

    directory = os.path.dirname(AGGREGATE_PATH)
    if directory:
        os.makedirs(directory, exist_ok=True)
    fd, temp_path = tempfile.mkstemp(prefix=".aggregate-", suffix=".json", dir=directory or None)
    try:
        with os.fdopen(fd, "wb") as file:
            file.write(payload)
        os.replace(temp_path, AGGREGATE_PATH)
    finally:
        if os.path.exists(temp_path):
            os.unlink(temp_path)


def day_bucket(state, day_key):
    days = state.setdefault("days", {})
    day = days.setdefault(day_key, {})
    day.setdefault("devices", {})
    day.setdefault("newDevices", {})
    day.setdefault("sessions", {})
    day.setdefault("eventCount", 0)
    day.setdefault("heartbeatCount", 0)
    day.setdefault("feedbackCount", 0)
    day.setdefault("errorCount", 0)
    day.setdefault("featureCounts", {})
    day.setdefault("layerCounts", {})
    return day


def increment(mapping, key, amount=1):
    mapping[key] = int(mapping.get(key, 0)) + amount


def update_aggregate_state(events):
    if not events:
        return
    with _aggregate_lock:
        state = load_aggregate_state()
        known_devices = state.setdefault("knownDevices", {})
        for event in events[:MAX_EVENTS_PER_REQUEST]:
            if not isinstance(event, dict):
                continue
            event_ms = parse_event_time(event.get("eventTime"))
            day = day_bucket(state, local_day_key(event_ms))
            event_name = sanitize_string(event.get("eventName"), 120)
            event_type = sanitize_string(event.get("eventType"), 120)
            device_id = sanitize_string(event.get("anonymousDeviceId"), 120)
            session_id = sanitize_string(event.get("sessionId"), 120)

            day["eventCount"] = int(day.get("eventCount", 0)) + 1
            if device_id:
                day["devices"][device_id] = 1
                if device_id not in known_devices:
                    known_devices[device_id] = event_ms
                    day["newDevices"][device_id] = 1
                else:
                    known_devices[device_id] = min(int(known_devices.get(device_id) or event_ms), event_ms)

            if session_id:
                try:
                    duration = float(event.get("durationSeconds") or 0)
                except (TypeError, ValueError):
                    duration = 0
                day["sessions"][session_id] = max(float(day["sessions"].get(session_id, 0)), duration)

            if event_type == "心跳" or event_name == "session_heartbeat":
                day["heartbeatCount"] = int(day.get("heartbeatCount", 0)) + 1
            if event_type == "反馈提交" or event_name == "feedback_submitted":
                day["feedbackCount"] = int(day.get("feedbackCount", 0)) + 1
            if event_type == "错误":
                day["errorCount"] = int(day.get("errorCount", 0)) + 1

            if event_name in CORE_EVENT_NAMES and event_name != "session_heartbeat":
                increment(day["featureCounts"], event_name)
                if event_name == "note_window_layer_changed":
                    properties = event.get("properties")
                    if not isinstance(properties, dict):
                        properties = {}
                    increment(day["layerCounts"], sanitize_string(properties.get("nextLayer") or "unknown", 40))
        save_aggregate_state(state)


def event_name_label(event_name):
    return EVENT_NAME_LABELS.get(event_name, event_name)


def module_label(module):
    return MODULE_LABELS.get(module, module)


def event_to_fields(event):
    properties = event.get("properties")
    if not isinstance(properties, dict):
        properties = {}
    else:
        properties = dict(properties)
    raw_event_name = sanitize_string(event.get("eventName"), 120)
    if raw_event_name and "eventNameRaw" not in properties:
        properties["eventNameRaw"] = raw_event_name
    event_type = sanitize_string(event.get("eventType"), 120)
    if event_type not in ALLOWED_EVENT_TYPES:
        event_type = "功能点击"
    module = sanitize_string(event.get("module"), 120)
    return {
        "事件名称": sanitize_string(event_name_label(raw_event_name), 120),
        "事件类型": event_type,
        "发生时间": parse_event_time(event.get("eventTime")),
        "匿名设备ID": sanitize_string(event.get("anonymousDeviceId"), 120),
        "会话ID": sanitize_string(event.get("sessionId"), 120),
        "应用版本": sanitize_string(event.get("appVersion"), 80),
        "系统版本": sanitize_string(event.get("systemVersion"), 160),
        "页面/模块": sanitize_string(module_label(module), 120),
        "停留时长秒": float(event.get("durationSeconds") or 0),
        "事件属性JSON": json.dumps(properties, ensure_ascii=False, separators=(",", ":"))[:5000],
        "来源": sanitize_string(event.get("source") or "小U待办", 80),
    }


def feedback_type_from_content(content):
    text = content.lower()
    if any(word in text for word in ("bug", "崩溃", "闪退", "错误", "无法", "不能")):
        return "Bug"
    if any(word in text for word in ("希望", "增加", "新增", "功能", "需求", "想要")):
        return "需求"
    if any(word in text for word in ("建议", "优化", "改进")):
        return "建议"
    return "其它"


def feedback_title(content):
    first_line = content.strip().splitlines()[0] if content.strip() else "用户反馈"
    first_line = first_line.strip()
    if len(first_line) > 36:
        return first_line[:36] + "..."
    return first_line or "用户反馈"


def feedback_event_to_fields(event):
    properties = event.get("properties")
    if not isinstance(properties, dict):
        properties = {}
    content = sanitize_string(properties.get("content"), 5000).strip()
    contact = sanitize_string(properties.get("contact"), 300).strip()
    return {
        "标题": feedback_title(content),
        "状态": "新提交",
        "创建时间": parse_event_time(event.get("eventTime")),
        "反馈类型": feedback_type_from_content(content),
        "描述": content,
        "联系方式": contact,
        "系统版本": sanitize_string(event.get("systemVersion"), 160),
        "应用版本": sanitize_string(event.get("appVersion"), 80),
        "匿名设备ID": sanitize_string(event.get("anonymousDeviceId"), 120),
        "来源": sanitize_string(event.get("source") or "小U待办", 80),
    }


def write_feedback_events(events):
    feedback_events = [
        event for event in events[:MAX_EVENTS_PER_REQUEST]
        if sanitize_string(event.get("eventName"), 120) == "feedback_submitted"
        or sanitize_string(event.get("eventType"), 120) == "反馈提交"
    ]
    if not feedback_events:
        return {"feedback_created": 0}

    table_id = feedback_table_id()
    if not table_id:
        raise RuntimeError("failed to find 用户反馈管理 table")

    records = [{"fields": feedback_event_to_fields(event)} for event in feedback_events]
    url = (
        "https://open.feishu.cn/open-apis/bitable/v1/apps/"
        f"{BASE_TOKEN}/tables/{table_id}/records/batch_create"
    )
    status, data = post_json(url, {"records": records}, feishu_headers())
    if status != 200 or data.get("code") != 0:
        raise RuntimeError(f"failed to write feedback: status={status} body={data}")
    return {"feedback_created": len(records), "feedback_records": data.get("data", {}).get("records", [])}


def should_store_event(event):
    event_name = sanitize_string(event.get("eventName"), 120)
    event_type = sanitize_string(event.get("eventType"), 120)
    if event_name == "session_heartbeat" or event_type == "心跳":
        return False
    return (
        event_name in CORE_EVENT_NAMES
        or event_type in {"反馈提交", "错误"}
    )


def write_telemetry_events(events):
    try:
        update_aggregate_state(events)
    except Exception as exc:
        log("aggregate update failed:", exc)
    feedback_result = write_feedback_events(events)
    records = [
        {"fields": event_to_fields(event)}
        for event in events[:MAX_EVENTS_PER_REQUEST]
        if should_store_event(event)
    ]
    if not records:
        return {"created": 0, **feedback_result}

    url = (
        "https://open.feishu.cn/open-apis/bitable/v1/apps/"
        f"{BASE_TOKEN}/tables/{TELEMETRY_TABLE_ID}/records/batch_create"
    )
    status, data = post_json(url, {"records": records}, feishu_headers())
    if status != 200 or data.get("code") != 0:
        raise RuntimeError(f"failed to write telemetry: status={status} body={data}")
    return {"created": len(records), "records": data.get("data", {}).get("records", []), **feedback_result}


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
