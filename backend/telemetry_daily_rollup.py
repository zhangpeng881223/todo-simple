#!/usr/bin/env python3
import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from collections import defaultdict
from datetime import datetime, time as dt_time, timedelta
from zoneinfo import ZoneInfo


APP_ID = os.environ.get("FEISHU_APP_ID", "")
APP_SECRET = os.environ.get("FEISHU_APP_SECRET", "")
BASE_TOKEN = os.environ.get("FEISHU_BASE_TOKEN", "")
TELEMETRY_TABLE_ID = os.environ.get("FEISHU_TELEMETRY_TABLE_ID", "")
DAILY_TABLE_ID = os.environ.get("FEISHU_DAILY_TABLE_ID", "")
LOCAL_TZ = ZoneInfo(os.environ.get("TELEMETRY_TIMEZONE", "Asia/Shanghai"))
MAX_RECORDS = int(os.environ.get("TELEMETRY_ROLLUP_MAX_RECORDS", "5000"))
AGGREGATE_PATH = os.environ.get("TELEMETRY_AGGREGATE_PATH", "/var/lib/xiaou-telemetry/aggregate-state.json")

EVENT_LABEL_TO_NAME = {
    "应用启动": "app_start",
    "应用退出": "app_exit",
    "使用心跳": "session_heartbeat",
    "用户反馈": "feedback_submitted",
    "主窗口AI总结": "note_ai_summary_clicked",
    "桌面待办AI总结": "desktop_ai_summary_clicked",
    "同步到日历": "calendar_sync",
    "总结本周": "ai_summary_week",
    "总结本月": "ai_summary_month",
    "桌面待办层级切换": "note_window_layer_changed",
}

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
            "FEISHU_DAILY_TABLE_ID": DAILY_TABLE_ID,
        }.items()
        if not value
    ]
    if missing:
        raise RuntimeError("missing env: " + ", ".join(missing))


def request_json(method, url, payload=None, headers=None):
    data = None
    if payload is not None:
        data = json.dumps(payload, ensure_ascii=False).encode("utf-8")
    request = urllib.request.Request(
        url,
        data=data,
        headers={
            "Content-Type": "application/json; charset=utf-8",
            **(headers or {}),
        },
        method=method,
    )
    try:
        with urllib.request.urlopen(request, timeout=15) as response:
            text = response.read().decode("utf-8")
            return response.status, json.loads(text or "{}")
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
    status, data = request_json(
        "POST",
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


def list_records(table_id, limit=MAX_RECORDS):
    records = []
    page_token = ""
    while len(records) < limit:
        params = {"page_size": min(500, limit - len(records))}
        if page_token:
            params["page_token"] = page_token
        url = (
            "https://open.feishu.cn/open-apis/bitable/v1/apps/"
            f"{BASE_TOKEN}/tables/{table_id}/records?"
            + urllib.parse.urlencode(params)
        )
        status, data = request_json("GET", url, headers=feishu_headers())
        if status != 200 or data.get("code") != 0:
            raise RuntimeError(f"failed to list records: status={status} body={data}")
        chunk = data.get("data", {}).get("items", [])
        records.extend(chunk)
        if not data.get("data", {}).get("has_more"):
            break
        page_token = data.get("data", {}).get("page_token", "")
        if not page_token:
            break
    return records


def create_record(table_id, fields):
    url = (
        "https://open.feishu.cn/open-apis/bitable/v1/apps/"
        f"{BASE_TOKEN}/tables/{table_id}/records"
    )
    status, data = request_json("POST", url, {"fields": fields}, feishu_headers())
    if status != 200 or data.get("code") != 0:
        raise RuntimeError(f"failed to create record: status={status} body={data}")
    return data.get("data", {}).get("record", {})


def update_record(table_id, record_id, fields):
    url = (
        "https://open.feishu.cn/open-apis/bitable/v1/apps/"
        f"{BASE_TOKEN}/tables/{table_id}/records/{record_id}"
    )
    status, data = request_json("PUT", url, {"fields": fields}, feishu_headers())
    if status != 200 or data.get("code") != 0:
        raise RuntimeError(f"failed to update record: status={status} body={data}")
    return data.get("data", {}).get("record", {})


def parse_ms(value):
    if isinstance(value, (int, float)):
        return int(value)
    return 0


def local_day_from_ms(ms):
    if not ms:
        return None
    return datetime.fromtimestamp(ms / 1000, LOCAL_TZ).date()


def day_bounds(target_day):
    start = datetime.combine(target_day, dt_time.min, LOCAL_TZ)
    end = start + timedelta(days=1)
    return int(start.timestamp() * 1000), int(end.timestamp() * 1000)


def day_key(target_day):
    return target_day.isoformat()


def load_aggregate_state():
    if not AGGREGATE_PATH:
        return None
    try:
        with open(AGGREGATE_PATH, "r", encoding="utf-8") as file:
            state = json.load(file)
    except FileNotFoundError:
        return None
    except (OSError, json.JSONDecodeError) as exc:
        log("aggregate load failed:", exc)
        return None
    if not isinstance(state, dict) or not isinstance(state.get("days"), dict):
        return None
    return state


def duration_distribution(durations):
    duration_buckets = {
        "0-1分钟": 0,
        "1-5分钟": 0,
        "5-15分钟": 0,
        "15-30分钟": 0,
        "30分钟以上": 0,
    }
    for duration in durations:
        if duration < 60:
            duration_buckets["0-1分钟"] += 1
        elif duration < 300:
            duration_buckets["1-5分钟"] += 1
        elif duration < 900:
            duration_buckets["5-15分钟"] += 1
        elif duration < 1800:
            duration_buckets["15-30分钟"] += 1
        else:
            duration_buckets["30分钟以上"] += 1
    return duration_buckets


def feature_summary_from_counts(core_feature_counts, layer_counts):
    return {
        "层级切换": core_feature_counts["note_window_layer_changed"],
        "层级-normal": layer_counts["normal"],
        "层级-bottom": layer_counts["bottom"],
        "层级-top": layer_counts["top"],
        "主窗口AI总结": core_feature_counts["note_ai_summary_clicked"],
        "桌面AI总结": core_feature_counts["desktop_ai_summary_clicked"],
        "同步到日历": core_feature_counts["calendar_sync"],
        "总结本周": core_feature_counts["ai_summary_week"],
        "总结本月": core_feature_counts["ai_summary_month"],
    }


def build_metrics_from_aggregate(state, target_day):
    target_start_ms, target_end_ms = day_bounds(target_day)
    week_start = target_day - timedelta(days=target_day.weekday())
    month_start = target_day.replace(day=1)
    days = state.get("days", {})
    target = days.get(day_key(target_day), {})

    total_users = {
        device_id
        for device_id, first_ms in state.get("knownDevices", {}).items()
        if parse_ms(first_ms) and parse_ms(first_ms) < target_end_ms
    }
    new_users = {
        device_id
        for device_id, first_ms in state.get("knownDevices", {}).items()
        if target_start_ms <= parse_ms(first_ms) < target_end_ms
    }

    dau = set(target.get("devices", {}).keys())
    wau = set()
    mau = set()
    for key, day in days.items():
        try:
            current_day = datetime.strptime(key, "%Y-%m-%d").date()
        except ValueError:
            continue
        if week_start <= current_day <= target_day:
            wau.update(day.get("devices", {}).keys())
        if month_start <= current_day <= target_day:
            mau.update(day.get("devices", {}).keys())

    sessions = target.get("sessions", {})
    durations = []
    for value in sessions.values():
        try:
            duration = float(value)
        except (TypeError, ValueError):
            duration = 0
        if duration > 0:
            durations.append(duration)
    avg_duration = sum(durations) / len(durations) if durations else 0

    core_feature_counts = defaultdict(int)
    for name, count in target.get("featureCounts", {}).items():
        core_feature_counts[name] = int(count or 0)
    layer_counts = defaultdict(int)
    for name, count in target.get("layerCounts", {}).items():
        layer_counts[name] = int(count or 0)
    feature_summary = feature_summary_from_counts(core_feature_counts, layer_counts)
    duration_buckets = duration_distribution(durations)

    return {
        "日期": int(datetime.combine(target_day, dt_time.min, LOCAL_TZ).timestamp() * 1000),
        "累计用户数": len(total_users),
        "新增用户数": len(new_users),
        "日活用户数": len(dau),
        "周活用户数": len(wau),
        "月活用户数": len(mau),
        "会话数": len(sessions),
        "事件数": int(target.get("eventCount", 0)),
        "心跳数": int(target.get("heartbeatCount", 0)),
        "反馈提交数": int(target.get("feedbackCount", 0)),
        "错误数": int(target.get("errorCount", 0)),
        "平均使用时长秒": round(avg_duration, 2),
        "数据备注": (
            f"自动汇总，来源=服务器聚合状态，"
            f"使用时长分布 {json.dumps(duration_buckets, ensure_ascii=False, separators=(',', ':'))}，"
            f"核心功能点击 {json.dumps(feature_summary, ensure_ascii=False, separators=(',', ':'))}，"
            f"生成时间 {datetime.now(LOCAL_TZ).strftime('%Y-%m-%d %H:%M:%S')}"
        ),
    }


def build_metrics(records, target_day):
    target_start_ms, target_end_ms = day_bounds(target_day)
    week_start = target_day - timedelta(days=target_day.weekday())
    week_start_ms, _ = day_bounds(week_start)
    month_start = target_day.replace(day=1)
    month_start_ms, _ = day_bounds(month_start)

    total_users = set()
    first_seen = {}
    dau = set()
    wau = set()
    mau = set()
    sessions = set()
    session_duration = defaultdict(float)
    event_count = 0
    heartbeat_count = 0
    feedback_count = 0
    error_count = 0
    core_feature_counts = defaultdict(int)
    layer_counts = defaultdict(int)

    for record in records:
        fields = record.get("fields", {})
        device_id = str(fields.get("匿名设备ID") or "").strip()
        session_id = str(fields.get("会话ID") or "").strip()
        event_type = fields.get("事件类型")
        if isinstance(event_type, list):
            event_type = event_type[0] if event_type else ""
        event_name = EVENT_LABEL_TO_NAME.get(str(fields.get("事件名称") or ""), str(fields.get("事件名称") or ""))
        event_ms = parse_ms(fields.get("发生时间"))
        if not device_id or not event_ms or event_ms >= target_end_ms:
            continue

        total_users.add(device_id)
        first_seen[device_id] = min(event_ms, first_seen.get(device_id, event_ms))

        if event_ms >= month_start_ms:
            mau.add(device_id)
        if event_ms >= week_start_ms:
            wau.add(device_id)
        if target_start_ms <= event_ms < target_end_ms:
            event_count += 1
            dau.add(device_id)
            if session_id:
                sessions.add(session_id)
                try:
                    session_duration[session_id] = max(session_duration[session_id], float(fields.get("停留时长秒") or 0))
                except (TypeError, ValueError):
                    pass
            if event_type == "心跳" or event_name == "session_heartbeat":
                heartbeat_count += 1
            if event_type == "反馈提交":
                feedback_count += 1
            if event_type == "错误":
                error_count += 1
            if event_name in {
                "note_window_layer_changed",
                "note_ai_summary_clicked",
                "desktop_ai_summary_clicked",
                "calendar_sync",
                "ai_summary_week",
                "ai_summary_month",
            }:
                core_feature_counts[event_name] += 1
                if event_name == "note_window_layer_changed":
                    try:
                        properties = json.loads(fields.get("事件属性JSON") or "{}")
                    except (TypeError, json.JSONDecodeError):
                        properties = {}
                    next_layer = str(properties.get("nextLayer") or "unknown")
                    layer_counts[next_layer] += 1

    new_users = {
        device_id
        for device_id, first_ms in first_seen.items()
        if target_start_ms <= first_ms < target_end_ms
    }
    durations = [duration for duration in session_duration.values() if duration > 0]
    avg_duration = sum(durations) / len(durations) if durations else 0
    duration_buckets = duration_distribution(durations)
    feature_summary = feature_summary_from_counts(core_feature_counts, layer_counts)

    return {
        "日期": int(datetime.combine(target_day, dt_time.min, LOCAL_TZ).timestamp() * 1000),
        "累计用户数": len(total_users),
        "新增用户数": len(new_users),
        "日活用户数": len(dau),
        "周活用户数": len(wau),
        "月活用户数": len(mau),
        "会话数": len(sessions),
        "事件数": event_count,
        "心跳数": heartbeat_count,
        "反馈提交数": feedback_count,
        "错误数": error_count,
        "平均使用时长秒": round(avg_duration, 2),
        "数据备注": (
            f"自动汇总，来源记录数 {len(records)}，"
            f"使用时长分布 {json.dumps(duration_buckets, ensure_ascii=False, separators=(',', ':'))}，"
            f"核心功能点击 {json.dumps(feature_summary, ensure_ascii=False, separators=(',', ':'))}，"
            f"生成时间 {datetime.now(LOCAL_TZ).strftime('%Y-%m-%d %H:%M:%S')}"
        ),
    }


def record_day(fields):
    return local_day_from_ms(parse_ms(fields.get("日期")))


def upsert_daily_metrics(fields):
    target_day = local_day_from_ms(parse_ms(fields["日期"]))
    existing_records = list_records(DAILY_TABLE_ID, limit=1000)
    for record in existing_records:
        if record_day(record.get("fields", {})) == target_day:
            return update_record(DAILY_TABLE_ID, record["record_id"], fields)
    return create_record(DAILY_TABLE_ID, fields)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--date", help="target date in YYYY-MM-DD, defaults to today in Asia/Shanghai")
    args = parser.parse_args()
    require_env()

    target_day = datetime.now(LOCAL_TZ).date()
    if args.date:
        target_day = datetime.strptime(args.date, "%Y-%m-%d").date()

    aggregate_state = load_aggregate_state()
    if aggregate_state:
        fields = build_metrics_from_aggregate(aggregate_state, target_day)
    else:
        telemetry_records = list_records(TELEMETRY_TABLE_ID)
        fields = build_metrics(telemetry_records, target_day)
    record = upsert_daily_metrics(fields)
    log("rollup ok", target_day.isoformat(), record.get("record_id", record.get("id", "")), fields)


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:
        log("fatal:", exc)
        sys.exit(1)
