#!/usr/bin/env python3
"""
Unity Bridge: 通过文件 IPC 调用 Unity Editor 中的 Bridge 工具。
跨平台 (macOS / Windows / Linux)。

IPC 目录: {projectRoot}/Temp/UnityBridge/

用法:
    python3 bridge.py <tool-name> [json-params]
    python3 bridge.py scene-list-opened
    python3 bridge.py scene-list-opened '{}'
    python3 bridge.py console-get-logs '{"count":10}'
"""

import json
import os
import sys
import time
import uuid
import hashlib
import ctypes
from ctypes import wintypes

TIMEOUT_SECONDS = 60
ASYNC_TIMEOUT_SECONDS = 300
POLL_INTERVAL = 0.1
HEARTBEAT_MAX_AGE = 10
EDITOR_LOG_RECENT_SECONDS = 120
LOCK_TIMEOUT_SECONDS = ASYNC_TIMEOUT_SECONDS + TIMEOUT_SECONDS + 30
LOCK_STALE_SECONDS = LOCK_TIMEOUT_SECONDS + 30
CLI_LOCK_WAIT_WARNING_SECONDS = 2
TESTS_RUN_SETTLE_TIMEOUT_SECONDS = 12
TESTS_RUN_SETTLE_HEARTBEAT_STEPS = 5
EDITOR_SET_STATE_SETTLE_TIMEOUT_SECONDS = 45
EDITOR_SET_STATE_GET_STATE_TIMEOUT_SECONDS = 15
EDITOR_SET_STATE_SETTLE_HEARTBEAT_TIMEOUT_SECONDS = 20
EDITOR_SET_STATE_SETTLE_HEARTBEAT_STEPS = 2
HEARTBEAT_READ_RETRY_COUNT = 20
HEARTBEAT_READ_RETRY_DELAY = 0.05
RESULT_READ_RETRY_COUNT = 20
RESULT_READ_RETRY_DELAY = 0.05
STDOUT_RESULT_MAX_BYTES = 24 * 1024
STDOUT_RESULT_PREVIEW_MAX_CHARS = 800
SCENE_LOCK_DEFAULT_TIMEOUT_SECONDS = 600
SCENE_LOCK_STALE_SECONDS = 600
AUDIT_PREVIEW_MAX_CHARS = 160
AUDIT_LOG_FILE_NAME = "command-audit.jsonl"

BRIDGE_SCENE_LOCK_TOKEN_PARAM = "bridgeSceneLockToken"
BRIDGE_SCENE_LOCK_MODE_PARAM = "bridgeSceneLockMode"
BRIDGE_SCENE_LOCK_TIMEOUT_PARAM = "bridgeSceneLockTimeoutSeconds"
BRIDGE_SCENE_LOCK_REASON_PARAM = "bridgeSceneLockReason"
BRIDGE_SCENE_DIRTY_POLICY_PARAM = "bridgeSceneDirtyPolicy"
BRIDGE_FORMAL_SCENE_RECOVERY_MODE_PARAM = "bridgeFormalSceneRecoveryMode"
BRIDGE_FORMAL_SCENE_RECOVERY_SCENES_PARAM = "bridgeFormalSceneRecoveryScenePaths"
BRIDGE_SCENE_LOCK_WRAPPER_PARAMS = {
    BRIDGE_SCENE_LOCK_TOKEN_PARAM,
    BRIDGE_SCENE_LOCK_MODE_PARAM,
    BRIDGE_SCENE_LOCK_TIMEOUT_PARAM,
    BRIDGE_SCENE_LOCK_REASON_PARAM,
    BRIDGE_SCENE_DIRTY_POLICY_PARAM,
    BRIDGE_FORMAL_SCENE_RECOVERY_MODE_PARAM,
    BRIDGE_FORMAL_SCENE_RECOVERY_SCENES_PARAM,
}

SCENE_LOCK_TOOL_STATUS = "scene-lock-status"
SCENE_LOCK_TOOL_ACQUIRE = "scene-lock-acquire"
SCENE_LOCK_TOOL_RELEASE = "scene-lock-release"
SCENE_LOCK_TOOL_NAMES = {
    SCENE_LOCK_TOOL_STATUS,
    SCENE_LOCK_TOOL_ACQUIRE,
    SCENE_LOCK_TOOL_RELEASE,
}

SCENE_LOCK_PROTECTED_TOOLS = {
    "assets-prefab-instantiate",
    "editor-application-set-state",
    "gameobject-component-add",
    "gameobject-component-destroy",
    "gameobject-component-modify",
    "gameobject-create",
    "gameobject-destroy",
    "gameobject-duplicate",
    "gameobject-modify",
    "gameobject-set-parent",
    "reflection-method-call",
    "scene-create",
    "scene-open",
    "scene-save",
    "scene-set-active",
    "scene-unload",
    "script-execute",
    "script-update-or-create",
    "tests-run",
}

SCENE_DIRTY_POLICY_REQUIRED_TOOLS = {
    "assets-prefab-instantiate",
    "editor-application-set-state",
    "gameobject-component-add",
    "gameobject-component-destroy",
    "gameobject-component-modify",
    "gameobject-create",
    "gameobject-destroy",
    "gameobject-duplicate",
    "gameobject-modify",
    "gameobject-set-parent",
    "reflection-method-call",
    "scene-create",
    "scene-open",
    "scene-save",
    "scene-unload",
    "script-execute",
    "script-update-or-create",
}

SAVE_DIALOG_TITLE_MARKERS = (
    "场景已更改",
    "Unsaved Changes Detected",
    "保存您在场景中所做的更改",
    "Save your changes in the scene",
)
SAVE_DIALOG_BODY_MARKERS = (
    "保存您在场景中所做的更改",
    "Save your changes in the scene",
    "如果不保存，您所做的更改将会丢失",
    "Your changes will be lost if you don't save them",
)

CONSUMED_COMMAND_GRACE_SECONDS = 20
GENERATED_SCENE_DIALOG_MARKERS = (
    "TestScene_",
    "__Backupscenes",
    "Assets/_Recovery/",
    "0.backup",
)
GENERATED_SCENE_EXACT_PATHS = (
    "Assets/Scenes/Gameplay/Scene_PlayableSwordmaster.unity",
)
GENERATED_SCENE_PATH_PREFIXES = (
    "Assets/Scenes/TestScenes/",
)
RECOVERY_SCENE_PATH_PREFIXES = (
    "Assets/_Recovery/",
    "Temp/__Backupscenes/",
)
DISCARD_BUTTON_NAMES = (
    "不保存",
    "Don't Save",
)
BM_CLICK = 0x00F5
SCENE_DIRTY_POLICY_VALUES = {
    "auto",
    "save-generated",
    "discard-generated",
    "ignore",
}
FORMAL_SCENE_RECOVERY_MODE_RELOAD_IF_DISK_CLEAN = "reload-if-disk-clean"


def get_project_root():
    """从 cwd 获取项目根目录（工作目录即项目根）"""
    return os.getcwd()


def error_exit(message):
    print(json.dumps({"status": "error", "message": message}), file=sys.stderr)
    sys.exit(1)


def warning_stderr(message):
    print(json.dumps({"status": "warning", "message": message}), file=sys.stderr)


def info_stderr(message):
    print(json.dumps({"status": "info", "message": message}), file=sys.stderr)


def normalize_project_path(path):
    return "" if not path else str(path).replace("\\", "/")


def get_bridge_dir(project_root):
    return os.path.join(project_root, "Temp", "UnityBridge")


def get_bridge_logs_dir(bridge_dir):
    return os.path.join(bridge_dir, "logs")


def get_command_audit_log_path(bridge_dir):
    return os.path.join(get_bridge_logs_dir(bridge_dir), AUDIT_LOG_FILE_NAME)


def get_scene_lock_path(bridge_dir):
    return os.path.join(bridge_dir, ".scene.lock")


def truncate_audit_text(value, limit=AUDIT_PREVIEW_MAX_CHARS):
    text = str(value)
    if len(text) <= limit:
        return text

    return f"{text[:limit]}...<trimmed {len(text) - limit} chars>"


def sanitize_audit_value(value, depth=0):
    if depth >= 3:
        return truncate_audit_text(value)

    if isinstance(value, dict):
        return {
            str(key): sanitize_audit_value(item, depth + 1)
            for key, item in list(value.items())[:24]
        }

    if isinstance(value, (list, tuple)):
        return [sanitize_audit_value(item, depth + 1) for item in list(value)[:24]]

    if isinstance(value, str):
        return truncate_audit_text(value)

    return value


def summarize_unity_params_for_audit(tool_name, params):
    if not isinstance(params, dict):
        return sanitize_audit_value(params)

    if tool_name == "script-execute":
        csharp_code = params.get("csharpCode")
        summary = {key: sanitize_audit_value(value) for key, value in params.items() if key != "csharpCode"}
        if isinstance(csharp_code, str):
            summary["csharpCodeLength"] = len(csharp_code)
            summary["csharpCodeSha1"] = hashlib.sha1(csharp_code.encode("utf-8")).hexdigest()
            summary["csharpCodePreview"] = truncate_audit_text(csharp_code)
        return summary

    return sanitize_audit_value(params)


def extract_result_status_for_audit(result_text):
    payload = try_parse_json(result_text)
    if not isinstance(payload, dict):
        return None

    return payload.get("status")


def summarize_result_for_audit(result_text):
    payload = try_parse_json(result_text)
    if not isinstance(payload, dict):
        return truncate_audit_text(result_text)

    summary = {}
    status = payload.get("status")
    if status is not None:
        summary["status"] = status

    message = payload.get("message")
    parsed_message = try_parse_json(message) if isinstance(message, str) else message
    if isinstance(parsed_message, (dict, list)):
        summary["message"] = sanitize_audit_value(parsed_message)
    elif message is not None:
        summary["message"] = truncate_audit_text(message)

    artifact_path = payload.get("artifactPath")
    if artifact_path:
        summary["artifactPath"] = artifact_path

    return summary


def should_capture_scene_dirty_audit(tool_name):
    return tool_name in SCENE_LOCK_PROTECTED_TOOLS


def try_capture_scene_dirty_summary(commands_dir, results_dir):
    try:
        return sanitize_audit_value(get_scene_dirty_summary(commands_dir, results_dir))
    except BaseException as ex:
        return {"captureError": truncate_audit_text(ex)}


def append_command_audit_entry(bridge_dir, entry):
    logs_dir = get_bridge_logs_dir(bridge_dir)
    os.makedirs(logs_dir, exist_ok=True)
    audit_log_path = get_command_audit_log_path(bridge_dir)
    with open(audit_log_path, "a", encoding="utf-8") as f:
        f.write(json.dumps(entry, ensure_ascii=False, separators=(",", ":")))
        f.write("\n")


def get_editor_log_path():
    if sys.platform.startswith("win"):
        local_appdata = os.environ.get("LOCALAPPDATA")
        if local_appdata:
            return os.path.join(local_appdata, "Unity", "Editor", "Editor.log")
    if sys.platform == "darwin":
        return os.path.expanduser("~/Library/Logs/Unity/Editor.log")
    return os.path.expanduser("~/.config/unity3d/Editor.log")


def get_unity_process_id():
    if not sys.platform.startswith("win"):
        return None

    try:
        import subprocess

        output = subprocess.check_output(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "(Get-Process Unity -ErrorAction SilentlyContinue | Select-Object -First 1 -ExpandProperty Id)"
            ],
            text=True,
        ).strip()
        return int(output) if output else None
    except Exception:
        return None


def get_foreground_unity_editor_process_id():
    if not sys.platform.startswith("win"):
        return get_unity_process_id()

    try:
        import subprocess

        command = r"""
$candidates = Get-Process Unity -ErrorAction SilentlyContinue |
    Where-Object { $_.MainWindowTitle -and $_.MainWindowTitle -match ' - Unity ' } |
    Sort-Object StartTime
if ($candidates) {
    $candidates[0].Id
}
"""
        output = subprocess.check_output(
            ["powershell", "-NoProfile", "-Command", command],
            text=True,
        ).strip()
        if output:
            return int(output)
    except Exception:
        pass

    return get_unity_process_id()


def dismiss_generated_scene_save_dialog_if_present():
    if not sys.platform.startswith("win"):
        return False

    unity_pid = get_foreground_unity_editor_process_id()
    if unity_pid is None:
        return False

    user32 = ctypes.windll.user32

    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    EnumChildProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)

    user32.EnumWindows.argtypes = [EnumWindowsProc, wintypes.LPARAM]
    user32.EnumWindows.restype = wintypes.BOOL
    user32.EnumChildWindows.argtypes = [wintypes.HWND, EnumChildProc, wintypes.LPARAM]
    user32.EnumChildWindows.restype = wintypes.BOOL
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetWindowThreadProcessId.restype = wintypes.DWORD
    user32.IsWindowVisible.argtypes = [wintypes.HWND]
    user32.IsWindowVisible.restype = wintypes.BOOL
    user32.GetWindowTextLengthW.argtypes = [wintypes.HWND]
    user32.GetWindowTextLengthW.restype = ctypes.c_int
    user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    user32.GetWindowTextW.restype = ctypes.c_int
    user32.SendMessageW.argtypes = [wintypes.HWND, wintypes.UINT, wintypes.WPARAM, wintypes.LPARAM]
    user32.SendMessageW.restype = wintypes.LPARAM

    def read_window_text(hwnd):
        length = user32.GetWindowTextLengthW(hwnd)
        buffer = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buffer, len(buffer))
        return buffer.value

    dialog_handles = []
    visible_window_titles = []

    def contains_any_marker(text, markers):
        if not text:
            return False

        return any(marker in text for marker in markers)

    @EnumWindowsProc
    def enum_windows(hwnd, lparam):
        process_id = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(process_id))
        if process_id.value != unity_pid or not user32.IsWindowVisible(hwnd):
            return True

        title = read_window_text(hwnd)
        if title:
            visible_window_titles.append(title)
        dialog_handles.append(hwnd)
        return True

    user32.EnumWindows(enum_windows, 0)

    for dialog_handle in dialog_handles:
        child_texts = []
        discard_buttons = []

        @EnumChildProc
        def enum_children(hwnd, lparam):
            text = read_window_text(hwnd)
            if text:
                child_texts.append(text)
                if text in DISCARD_BUTTON_NAMES:
                    discard_buttons.append(hwnd)
            return True

        user32.EnumChildWindows(dialog_handle, enum_children, 0)
        dialog_text = "\n".join(child_texts)
        dialog_title = read_window_text(dialog_handle)
        title_suggests_save_dialog = contains_any_marker(dialog_title, SAVE_DIALOG_TITLE_MARKERS)
        body_suggests_save_dialog = contains_any_marker(dialog_text, SAVE_DIALOG_BODY_MARKERS)
        if not title_suggests_save_dialog and not body_suggests_save_dialog:
            continue

        title_suggests_generated_scene = any(
            marker in title
            for title in visible_window_titles
            for marker in GENERATED_SCENE_DIALOG_MARKERS
        )
        body_suggests_generated_scene = any(marker in dialog_text for marker in GENERATED_SCENE_DIALOG_MARKERS)

        if not title_suggests_generated_scene and not body_suggests_generated_scene:
            continue

        if not discard_buttons:
            continue

        user32.SendMessageW(discard_buttons[0], BM_CLICK, 0, 0)
        return True

    return False


def detect_blocking_unity_save_dialog():
    if not sys.platform.startswith("win"):
        return None

    unity_pid = get_foreground_unity_editor_process_id()
    if unity_pid is None:
        return None

    user32 = ctypes.windll.user32

    EnumWindowsProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)
    EnumChildProc = ctypes.WINFUNCTYPE(ctypes.c_bool, wintypes.HWND, wintypes.LPARAM)

    user32.EnumWindows.argtypes = [EnumWindowsProc, wintypes.LPARAM]
    user32.EnumWindows.restype = wintypes.BOOL
    user32.EnumChildWindows.argtypes = [wintypes.HWND, EnumChildProc, wintypes.LPARAM]
    user32.EnumChildWindows.restype = wintypes.BOOL
    user32.GetWindowThreadProcessId.argtypes = [wintypes.HWND, ctypes.POINTER(wintypes.DWORD)]
    user32.GetWindowThreadProcessId.restype = wintypes.DWORD
    user32.IsWindowVisible.argtypes = [wintypes.HWND]
    user32.IsWindowVisible.restype = wintypes.BOOL
    user32.GetWindowTextLengthW.argtypes = [wintypes.HWND]
    user32.GetWindowTextLengthW.restype = ctypes.c_int
    user32.GetWindowTextW.argtypes = [wintypes.HWND, wintypes.LPWSTR, ctypes.c_int]
    user32.GetWindowTextW.restype = ctypes.c_int

    def read_window_text(hwnd):
        length = user32.GetWindowTextLengthW(hwnd)
        buffer = ctypes.create_unicode_buffer(length + 1)
        user32.GetWindowTextW(hwnd, buffer, len(buffer))
        return buffer.value

    def contains_any_marker(text, markers):
        if not text:
            return False

        return any(marker in text for marker in markers)

    visible_window_titles = []
    dialog_handles = []

    @EnumWindowsProc
    def enum_windows(hwnd, lparam):
        process_id = wintypes.DWORD()
        user32.GetWindowThreadProcessId(hwnd, ctypes.byref(process_id))
        if process_id.value != unity_pid or not user32.IsWindowVisible(hwnd):
            return True

        title = read_window_text(hwnd)
        if title:
            visible_window_titles.append(title)
        dialog_handles.append(hwnd)
        return True

    user32.EnumWindows(enum_windows, 0)

    for dialog_handle in dialog_handles:
        dialog_title = read_window_text(dialog_handle)
        child_texts = []

        @EnumChildProc
        def enum_children(hwnd, lparam):
            text = read_window_text(hwnd)
            if text:
                child_texts.append(text)
            return True

        user32.EnumChildWindows(dialog_handle, enum_children, 0)
        dialog_text = "\n".join(child_texts)

        title_suggests_save_dialog = contains_any_marker(dialog_title, SAVE_DIALOG_TITLE_MARKERS)
        body_suggests_save_dialog = contains_any_marker(dialog_text, SAVE_DIALOG_BODY_MARKERS)
        if not title_suggests_save_dialog and not body_suggests_save_dialog:
            continue

        title_suggests_generated_scene = any(
            marker in title
            for title in visible_window_titles
            for marker in GENERATED_SCENE_DIALOG_MARKERS
        )
        body_suggests_generated_scene = any(marker in dialog_text for marker in GENERATED_SCENE_DIALOG_MARKERS)
        if title_suggests_generated_scene or body_suggests_generated_scene:
            continue

        return {
            "title": dialog_title,
            "body": dialog_text,
        }

    return None


def fail_if_blocking_unity_save_dialog():
    dialog = detect_blocking_unity_save_dialog()
    if dialog is None:
        return

    title = dialog.get("title") or "未知保存弹窗"
    error_exit(
        "Unity Editor 当前被正式场景保存确认弹窗阻塞，AIBridge 不会擅自替用户决定保存或丢弃未保存改动。"
        f" 请先处理该弹窗后再继续。Window: {title}"
    )


def is_editor_log_recent():
    editor_log = get_editor_log_path()
    if not os.path.exists(editor_log):
        return False

    try:
        age = time.time() - os.path.getmtime(editor_log)
        return age <= EDITOR_LOG_RECENT_SECONDS
    except OSError:
        return False


def try_get_mtime(path):
    try:
        return os.path.getmtime(path)
    except OSError:
        return None


def detect_bridge_activity_after_heartbeat(bridge_dir, heartbeat_file):
    heartbeat_mtime = try_get_mtime(heartbeat_file)
    if heartbeat_mtime is None:
        return None

    evidence_paths = [
        ("bridge results dir", os.path.join(bridge_dir, "results")),
        ("bridge commands dir", os.path.join(bridge_dir, "commands")),
        ("Unity Editor.log", get_editor_log_path()),
    ]

    for label, path in evidence_paths:
        mtime = try_get_mtime(path)
        if mtime is None:
            continue

        if mtime > heartbeat_mtime:
            return {
                "label": label,
                "seconds_newer": int(mtime - heartbeat_mtime),
            }

    return None


def check_heartbeat(bridge_dir):
    heartbeat_file = os.path.join(bridge_dir, "heartbeat")
    heartbeat_ts = read_heartbeat_timestamp(bridge_dir)
    if heartbeat_ts is None:
        error_exit("Failed to parse Unity Editor heartbeat")

    age = time.time() - heartbeat_ts
    if age > HEARTBEAT_MAX_AGE:
        bridge_activity = detect_bridge_activity_after_heartbeat(bridge_dir, heartbeat_file)
        if bridge_activity is not None:
            print(
                json.dumps(
                    {
                        "status": "warning",
                        "message": (
                            f"Unity Editor heartbeat stale ({int(age)}s old), "
                            f"but {bridge_activity['label']} is {bridge_activity['seconds_newer']}s newer than heartbeat. "
                            "Continuing and letting the command result decide."
                        ),
                    }
                ),
                file=sys.stderr,
            )
            return {"heartbeat_stale": True, "fallback": bridge_activity["label"]}

        if is_editor_log_recent():
            print(
                json.dumps(
                    {
                        "status": "warning",
                        "message": (
                            f"Unity Editor heartbeat stale ({int(age)}s old), "
                            "but Editor.log is still updating. Continuing and letting the command result decide."
                        ),
                    }
                ),
                file=sys.stderr,
            )
            return {"heartbeat_stale": True, "fallback": "editor-log-recent"}

        error_exit(f"Unity Editor heartbeat stale ({int(age)}s old). Editor may be compiling or frozen.")

    return {"heartbeat_stale": False, "fallback": None}


def read_heartbeat_timestamp(bridge_dir, fatal=True):
    heartbeat_file = os.path.join(bridge_dir, "heartbeat")
    if not os.path.exists(heartbeat_file):
        if fatal:
            error_exit("Unity Editor not running (Temp/UnityBridge/heartbeat not found)")
        return None

    last_error = None
    for attempt in range(HEARTBEAT_READ_RETRY_COUNT):
        try:
            with open(heartbeat_file, "r", encoding="utf-8") as f:
                data = json.load(f)
            return int(data["timestamp"]) / 1000.0
        except (PermissionError, OSError, json.JSONDecodeError, KeyError, ValueError) as e:
            last_error = e
            if attempt + 1 < HEARTBEAT_READ_RETRY_COUNT:
                time.sleep(HEARTBEAT_READ_RETRY_DELAY)
                continue

    if fatal:
        error_exit(f"Failed to parse heartbeat: {last_error}")
    return None


def wait_for_heartbeat_steps(bridge_dir, baseline_timestamp, required_steps, timeout_seconds):
    deadline = time.time() + timeout_seconds
    steps_observed = 0
    last_timestamp = baseline_timestamp

    while time.time() < deadline:
        time.sleep(POLL_INTERVAL)
        current_timestamp = read_heartbeat_timestamp(bridge_dir, fatal=False)
        if current_timestamp is None:
            continue

        if current_timestamp > last_timestamp:
            steps_observed += 1
            last_timestamp = current_timestamp
            if steps_observed >= required_steps:
                return True

    return False


def write_atomic(path, content):
    """原子写入：先写 .tmp 再 rename"""
    tmp_path = path + ".tmp"
    with open(tmp_path, "w", encoding="utf-8") as f:
        f.write(content)
    os.replace(tmp_path, path)


def cleanup_file(path):
    try:
        os.remove(path)
    except OSError:
        pass


def try_parse_lock_info(text):
    payload = try_parse_json(text)
    return payload if isinstance(payload, dict) else None


def read_lock_info(lock_path):
    try:
        with open(lock_path, "r", encoding="utf-8") as f:
            return try_parse_lock_info(f.read())
    except OSError:
        return None


def is_pid_running(pid):
    try:
        pid = int(pid)
    except (TypeError, ValueError):
        return True

    if pid <= 0:
        return True

    if sys.platform.startswith("win"):
        try:
            import subprocess

            subprocess.check_output(
                [
                    "powershell",
                    "-NoProfile",
                    "-Command",
                    f"Get-Process -Id {pid} -ErrorAction Stop | Out-Null"
                ],
                stderr=subprocess.DEVNULL,
                text=True,
            )
            return True
        except Exception:
            return False

    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True
    except (OSError, SystemError):
        return True


def is_lock_stale(lock_path, stale_seconds, check_pid=True):
    lock_info = read_lock_info(lock_path)
    if isinstance(lock_info, dict):
        pid = lock_info.get("pid")
        if check_pid and pid is not None and not is_pid_running(pid):
            return True

        try:
            timestamp = float(lock_info.get("timestamp", 0.0))
            if timestamp > 0.0 and (time.time() - timestamp) > stale_seconds:
                return True
        except (TypeError, ValueError):
            pass

    try:
        modified_age = time.time() - os.path.getmtime(lock_path)
        return modified_age > stale_seconds
    except OSError:
        return False


def format_lock_holder(lock_info):
    if not isinstance(lock_info, dict):
        return "unknown holder"

    holder_parts = []
    owner = lock_info.get("owner")
    reason = lock_info.get("reason")
    tool = lock_info.get("tool")
    pid = lock_info.get("pid")

    if owner:
        holder_parts.append(f"owner={owner}")
    if reason:
        holder_parts.append(f"reason={reason}")
    if tool:
        holder_parts.append(f"tool={tool}")
    if pid:
        holder_parts.append(f"pid={pid}")

    return ", ".join(holder_parts) if holder_parts else "unknown holder"


def build_scene_lock_payload(token, owner, reason, track_pid):
    timestamp = time.time()
    return {
        "token": token,
        "owner": owner,
        "reason": reason,
        "pid": os.getpid() if track_pid else None,
        "pidTracked": bool(track_pid),
        "timestamp": timestamp,
    }


def should_check_scene_lock_pid(lock_info):
    if not isinstance(lock_info, dict):
        return False

    if "pidTracked" in lock_info:
        return bool(lock_info.get("pidTracked"))

    return lock_info.get("pid") is not None


def write_lock_file_exclusive(lock_path, lock_payload):
    lock_dir = os.path.dirname(lock_path)
    if lock_dir:
        os.makedirs(lock_dir, exist_ok=True)
    fd = os.open(lock_path, os.O_CREAT | os.O_EXCL | os.O_WRONLY)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(lock_payload, f)


def parse_scene_lock_mode(value):
    if value is None:
        return "wait"

    normalized = str(value).strip().lower()
    if normalized in {"wait", "fail"}:
        return normalized

    error_exit(
        f"Invalid {BRIDGE_SCENE_LOCK_MODE_PARAM}: {value}. "
        'Expected "wait" or "fail".'
    )


def parse_scene_lock_timeout(value):
    if value is None:
        return SCENE_LOCK_DEFAULT_TIMEOUT_SECONDS

    try:
        timeout_seconds = float(value)
    except (TypeError, ValueError):
        error_exit(
            f"Invalid {BRIDGE_SCENE_LOCK_TIMEOUT_PARAM}: {value}. "
            "Expected a positive number of seconds."
        )

    if timeout_seconds <= 0:
        error_exit(
            f"Invalid {BRIDGE_SCENE_LOCK_TIMEOUT_PARAM}: {value}. "
            "Expected a positive number of seconds."
        )

    return timeout_seconds


def is_scene_lock_required(tool_name, params):
    if tool_name == "tests-run":
        return str(params.get("testMode", "EditMode")) == "PlayMode"

    return tool_name in SCENE_LOCK_PROTECTED_TOOLS


def refresh_scene_lock(lock_path, lock_info):
    updated_lock_info = dict(lock_info)
    if should_check_scene_lock_pid(lock_info):
        updated_lock_info["pid"] = os.getpid()
    updated_lock_info["timestamp"] = time.time()
    write_atomic(lock_path, json.dumps(updated_lock_info))
    return updated_lock_info


def acquire_scene_lock(lock_path, owner, reason, mode, timeout_seconds, track_pid):
    start_time = time.time()

    while True:
        lock_payload = build_scene_lock_payload(
            token=uuid.uuid4().hex,
            owner=owner,
            reason=reason,
            track_pid=track_pid,
        )

        try:
            write_lock_file_exclusive(lock_path, lock_payload)
            return lock_payload
        except (FileExistsError, PermissionError):
            existing_lock_info = read_lock_info(lock_path)
            if is_lock_stale(
                lock_path,
                SCENE_LOCK_STALE_SECONDS,
                check_pid=should_check_scene_lock_pid(existing_lock_info),
            ):
                cleanup_file(lock_path)
                continue

            lock_info = existing_lock_info
            if mode == "fail":
                error_exit(
                    "AIBridge 场景锁已被占用，当前端到端/场景操作应放弃。 "
                    f"Holder: {format_lock_holder(lock_info)}."
                )

            elapsed = time.time() - start_time
            if elapsed >= timeout_seconds:
                error_exit(
                    f"Timeout after {int(timeout_seconds)}s waiting for AIBridge scene lock. "
                    f"Holder: {format_lock_holder(lock_info)}."
                )

            time.sleep(POLL_INTERVAL)
        except OSError as e:
            error_exit(f"Failed to acquire AIBridge scene lock: {e}")


def ensure_owned_scene_lock(lock_path, token):
    current_lock_info = read_lock_info(lock_path)
    if is_lock_stale(
        lock_path,
        SCENE_LOCK_STALE_SECONDS,
        check_pid=should_check_scene_lock_pid(current_lock_info),
    ):
        cleanup_file(lock_path)
        error_exit("AIBridge 场景锁已过期并被清理；请重新获取 scene lock 后再继续。")

    lock_info = current_lock_info
    if not isinstance(lock_info, dict):
        error_exit("AIBridge 场景锁不存在；请先获取 scene lock。")

    if lock_info.get("token") != token:
        error_exit(
            "当前命令未持有 AIBridge 场景锁，禁止继续执行场景端到端/场景改动命令。 "
            f"Holder: {format_lock_holder(lock_info)}."
        )

    return refresh_scene_lock(lock_path, lock_info)


def release_scene_lock(lock_path, token):
    if not os.path.exists(lock_path):
        return {"released": False, "locked": False}

    current_lock_info = read_lock_info(lock_path)
    if is_lock_stale(
        lock_path,
        SCENE_LOCK_STALE_SECONDS,
        check_pid=should_check_scene_lock_pid(current_lock_info),
    ):
        cleanup_file(lock_path)
        return {"released": False, "locked": False, "staleCleared": True}

    lock_info = current_lock_info
    if not isinstance(lock_info, dict):
        cleanup_file(lock_path)
        return {"released": False, "locked": False}

    if lock_info.get("token") != token:
        error_exit(
            "AIBridge 场景锁 release token 不匹配，禁止释放他人的场景锁。 "
            f"Holder: {format_lock_holder(lock_info)}."
        )

    cleanup_file(lock_path)
    return {
        "released": True,
        "locked": False,
        "owner": lock_info.get("owner"),
        "reason": lock_info.get("reason"),
        "token": token,
    }


def get_scene_lock_status(lock_path):
    if not os.path.exists(lock_path):
        return {"locked": False}

    lock_info = read_lock_info(lock_path)
    stale = is_lock_stale(
        lock_path,
        SCENE_LOCK_STALE_SECONDS,
        check_pid=should_check_scene_lock_pid(lock_info),
    )
    if stale:
        cleanup_file(lock_path)
        result = {
            "locked": False,
            "staleCleared": True,
        }
        if isinstance(lock_info, dict):
            result["expiredLock"] = lock_info
        return result

    result = {
        "locked": True,
        "stale": stale,
    }
    if isinstance(lock_info, dict):
        result["lock"] = lock_info
    return result


def handle_scene_lock_tool(tool_name, params, bridge_dir):
    lock_path = get_scene_lock_path(bridge_dir)
    os.makedirs(bridge_dir, exist_ok=True)

    if tool_name == SCENE_LOCK_TOOL_STATUS:
        print(json.dumps(get_scene_lock_status(lock_path), ensure_ascii=False))
        return True

    if tool_name == SCENE_LOCK_TOOL_ACQUIRE:
        if not params:
            error_exit(
                'scene-lock-acquire requires an explicit JSON payload. '
                'Pass at least "owner" or "reason" so a probe command does not silently grab a 10-minute scene lock.'
            )
        owner = str(params.get("owner") or f"pid-{os.getpid()}").strip()
        reason = str(params.get("reason") or "AIBridge 场景端到端占用").strip()
        mode = parse_scene_lock_mode(params.get("mode"))
        timeout_seconds = parse_scene_lock_timeout(params.get("timeoutSeconds"))
        lock_payload = acquire_scene_lock(lock_path, owner, reason, mode, timeout_seconds, track_pid=False)
        print(json.dumps({"locked": True, "lock": lock_payload}, ensure_ascii=False))
        return True

    if tool_name == SCENE_LOCK_TOOL_RELEASE:
        token = params.get("token")
        if not isinstance(token, str) or not token.strip():
            error_exit('scene-lock-release requires a non-empty "token".')

        print(json.dumps(release_scene_lock(lock_path, token.strip()), ensure_ascii=False))
        return True

    return False


def split_bridge_wrapper_params(params):
    if not isinstance(params, dict):
        error_exit("Bridge params must be a JSON object.")

    unity_params = dict(params)
    wrapper_params = {}
    for key in BRIDGE_SCENE_LOCK_WRAPPER_PARAMS:
        if key in unity_params:
            wrapper_params[key] = unity_params.pop(key)

    return unity_params, wrapper_params


def parse_formal_scene_recovery_mode(value):
    if value is None:
        return None

    normalized = str(value).strip().lower()
    if normalized == FORMAL_SCENE_RECOVERY_MODE_RELOAD_IF_DISK_CLEAN:
        return normalized

    error_exit(
        f"Invalid {BRIDGE_FORMAL_SCENE_RECOVERY_MODE_PARAM}: {value}. "
        f'Expected "{FORMAL_SCENE_RECOVERY_MODE_RELOAD_IF_DISK_CLEAN}".'
    )


def parse_formal_scene_recovery_scene_paths(value):
    if value is None:
        return []

    if isinstance(value, str):
        normalized = normalize_project_path(value.strip())
        return [normalized] if normalized else []

    if isinstance(value, list):
        result = []
        for item in value:
            normalized = normalize_project_path(str(item).strip())
            if normalized:
                result.append(normalized)
        return result

    error_exit(
        f"Invalid {BRIDGE_FORMAL_SCENE_RECOVERY_SCENES_PARAM}: expected string or string array."
    )


def parse_scene_dirty_policy(value):
    if value is None:
        return "auto"

    normalized = str(value).strip().lower()
    if normalized in SCENE_DIRTY_POLICY_VALUES:
        return normalized

    error_exit(
        f"Invalid {BRIDGE_SCENE_DIRTY_POLICY_PARAM}: {value}. "
        'Expected "auto", "save-generated", "discard-generated", or "ignore".'
    )


def is_explicit_scene_dirty_policy_required(tool_name):
    return tool_name in SCENE_DIRTY_POLICY_REQUIRED_TOOLS


def resolve_scene_dirty_policy(tool_name, unity_params, wrapper_params):
    requested_policy = parse_scene_dirty_policy(wrapper_params.get(BRIDGE_SCENE_DIRTY_POLICY_PARAM))
    scene_lock_token = wrapper_params.get(BRIDGE_SCENE_LOCK_TOKEN_PARAM)
    has_explicit_scene_lock_token = isinstance(scene_lock_token, str) and bool(scene_lock_token.strip())

    if requested_policy == "ignore" and tool_name == "scene-save":
        return "ignore"

    if requested_policy == "ignore" and not has_explicit_scene_lock_token:
        error_exit(
            f"{BRIDGE_SCENE_DIRTY_POLICY_PARAM}=\"ignore\" 只允许用于已显式持有 scene lock 的多步场景流程。"
            f" {tool_name} 若要临时保留 generated scene dirty，必须先通过 {SCENE_LOCK_TOOL_ACQUIRE} 获取锁，"
            f"后续命令显式传 {BRIDGE_SCENE_LOCK_TOKEN_PARAM}，并在同一流程内再用 "
            "\"save-generated\" 或 \"discard-generated\" 正式收尾。"
        )

    if requested_policy != "auto":
        return requested_policy

    if tool_name == "tests-run" and str(unity_params.get("testMode", "EditMode")) == "PlayMode":
        return "discard-generated"

    if tool_name == "scene-save":
        return "ignore"

    if is_explicit_scene_dirty_policy_required(tool_name):
        error_exit(
            f"{tool_name} 可能修改场景或留下 dirty 状态，"
            f"必须显式传 {BRIDGE_SCENE_DIRTY_POLICY_PARAM}。"
            ' 可选值：'
            '"save-generated"、"discard-generated"、"ignore"。'
            ' 其中 "ignore" 只允许用于你明确要跨多条命令暂存 dirty，'
            '并且后续会在同一流程里显式保存或丢弃生成场景的情况。'
        )

    return "ignore"


def acquire_scene_lock_for_command(lock_path, tool_name, wrapper_params):
    if not is_scene_lock_required(tool_name, wrapper_params.get("_unityParams", {})):
        return None

    token = wrapper_params.get(BRIDGE_SCENE_LOCK_TOKEN_PARAM)
    if isinstance(token, str) and token.strip():
        owned_lock = ensure_owned_scene_lock(lock_path, token.strip())
        return {
            "autoRelease": False,
            "lock": owned_lock,
        }

    mode = parse_scene_lock_mode(wrapper_params.get(BRIDGE_SCENE_LOCK_MODE_PARAM))
    timeout_seconds = parse_scene_lock_timeout(wrapper_params.get(BRIDGE_SCENE_LOCK_TIMEOUT_PARAM))
    reason = wrapper_params.get(BRIDGE_SCENE_LOCK_REASON_PARAM)
    if not isinstance(reason, str) or not reason.strip():
        reason = f"{tool_name} scene-protected command"

    lock_payload = acquire_scene_lock(
        lock_path,
        owner=f"auto-{tool_name}",
        reason=reason,
        mode=mode,
        timeout_seconds=timeout_seconds,
        track_pid=True,
    )
    return {
        "autoRelease": True,
        "lock": lock_payload,
    }


def acquire_cli_lock(lock_path, command_id, tool_name):
    start_time = time.time()
    warned_wait = False

    while True:
        lock_payload = {
            "pid": os.getpid(),
            "commandId": command_id,
            "tool": tool_name,
            "timestamp": time.time(),
        }

        try:
            write_lock_file_exclusive(lock_path, lock_payload)
            return
        except FileNotFoundError:
            # Temp/UnityBridge 可能在 Unity 重载或外部清理时瞬间消失；重建目录后继续抢锁。
            lock_dir = os.path.dirname(lock_path)
            if lock_dir:
                os.makedirs(lock_dir, exist_ok=True)
            time.sleep(POLL_INTERVAL)
            continue
        except (FileExistsError, PermissionError):
            if is_lock_stale(lock_path, LOCK_STALE_SECONDS):
                cleanup_file(lock_path)
                continue

            if not os.path.exists(lock_path):
                # 竞争窗口里锁文件可能已被其它进程释放；直接重试，不要把瞬时缺失升级成失败。
                time.sleep(POLL_INTERVAL)
                continue

            elapsed = time.time() - start_time
            if not warned_wait and elapsed >= CLI_LOCK_WAIT_WARNING_SECONDS:
                lock_info = read_lock_info(lock_path)
                holder_suffix = ""
                if isinstance(lock_info, dict):
                    holder_pid = lock_info.get("pid")
                    holder_tool = lock_info.get("tool")
                    holder_command_id = lock_info.get("commandId")
                    holder_suffix = (
                        f" 当前持有者 pid={holder_pid}, tool={holder_tool}, commandId={holder_command_id}."
                    )

                warning_stderr(
                    f"AIBridge CLI lock 正在排队，当前命令 {tool_name} 已等待 {elapsed:.1f}s。"
                    f"{holder_suffix}"
                )
                warned_wait = True

            if elapsed >= LOCK_TIMEOUT_SECONDS:
                lock_info = read_lock_info(lock_path)
                holder = ""
                if isinstance(lock_info, dict):
                    pid = lock_info.get("pid")
                    holder_tool = lock_info.get("tool")
                    holder_command_id = lock_info.get("commandId")
                    holder = (
                        f" Lock holder pid={pid}, tool={holder_tool}, commandId={holder_command_id}."
                    )
                error_exit(
                    f"Timeout after {LOCK_TIMEOUT_SECONDS}s waiting for AIBridge CLI lock "
                    f"(tool: {tool_name}).{holder}"
                )

            time.sleep(POLL_INTERVAL)
        except OSError as e:
            error_exit(f"Failed to acquire AIBridge CLI lock: {e}")


def release_cli_lock(lock_path):
    cleanup_file(lock_path)


def wait_for_result(result_file, timeout_seconds):
    deadline = time.time() + timeout_seconds

    while time.time() < deadline:
        if os.path.exists(result_file):
            result_text = try_read_result_file(result_file)
            if result_text is not None:
                return result_text

        time.sleep(POLL_INTERVAL)

    # 避免 Unity 在超时边界刚写完结果文件时被误判为无回包。
    if os.path.exists(result_file):
        return try_read_result_file(result_file)

    return None


def wait_for_consumed_command_result(command_file, result_file, timeout_seconds):
    deadline = time.time() + timeout_seconds

    while time.time() < deadline:
        if os.path.exists(result_file):
            result_text = try_read_result_file(result_file)
            if result_text is not None:
                return result_text

        if os.path.exists(command_file):
            return None

        time.sleep(POLL_INTERVAL)

    if os.path.exists(result_file):
        return try_read_result_file(result_file)

    return None


def try_read_result_file(result_file):
    last_error = None
    for attempt in range(RESULT_READ_RETRY_COUNT):
        try:
            with open(result_file, "r", encoding="utf-8") as f:
                return f.read()
        except (PermissionError, OSError) as e:
            last_error = e
            if attempt + 1 < RESULT_READ_RETRY_COUNT:
                time.sleep(RESULT_READ_RETRY_DELAY)

    warning_stderr(f"Failed to read Unity Bridge result file after retries: {last_error}")
    return None


def try_parse_json(text):
    try:
        return json.loads(text)
    except (TypeError, json.JSONDecodeError):
        return None


def safe_filename_segment(value):
    segment = str(value) if value is not None else "unknown"
    cleaned = []
    for ch in segment:
        cleaned.append(ch if ch.isalnum() or ch in {"-", "_"} else "_")
    return "".join(cleaned) or "unknown"


def shorten_text(text, max_chars):
    if not isinstance(text, str):
        return text

    if max_chars <= 0 or len(text) <= max_chars:
        return text

    return text[:max_chars] + "..."


def build_console_log_preview(entries):
    preview = []
    if not isinstance(entries, list):
        return preview

    for entry in entries[:3]:
        if not isinstance(entry, dict):
            continue

        preview_entry = {}
        log_type = entry.get("logType")
        message = entry.get("message")
        stack_trace = entry.get("stackTrace")

        if log_type is not None:
            preview_entry["logType"] = log_type
        if isinstance(message, str) and message:
            preview_entry["message"] = shorten_text(message, STDOUT_RESULT_PREVIEW_MAX_CHARS)
        if isinstance(stack_trace, str) and stack_trace:
            preview_entry["stackTrace"] = shorten_text(stack_trace.splitlines()[0], STDOUT_RESULT_PREVIEW_MAX_CHARS)

        preview.append(preview_entry)

    return preview


def write_result_artifact(results_dir, command_id, tool_name, result_text):
    artifacts_dir = os.path.join(results_dir, "artifacts")
    os.makedirs(artifacts_dir, exist_ok=True)

    artifact_name = f"{command_id}-{safe_filename_segment(tool_name)}.json"
    artifact_path = os.path.join(artifacts_dir, artifact_name)
    write_atomic(artifact_path, result_text)
    return artifact_path


def strip_console_stack_traces_if_requested(tool_name, params, result_text):
    if tool_name != "console-get-logs":
        return result_text

    include_stack_trace = bool(params.get("includeStackTrace", False))
    if include_stack_trace:
        return result_text

    payload = try_parse_json(result_text)
    if not isinstance(payload, dict):
        return result_text

    message = payload.get("message")
    parsed_message = try_parse_json(message) if isinstance(message, str) else message
    if not isinstance(parsed_message, list):
        return result_text

    changed = False
    for entry in parsed_message:
        if isinstance(entry, dict) and "stackTrace" in entry:
            entry.pop("stackTrace", None)
            changed = True

    if not changed:
        return result_text

    updated_payload = dict(payload)
    updated_payload["message"] = json.dumps(parsed_message, ensure_ascii=False, separators=(",", ":"))
    return json.dumps(updated_payload, ensure_ascii=False, separators=(",", ":"))


def prepare_stdout_result(tool_name, params, result_text, results_dir, command_id):
    result_text = strip_console_stack_traces_if_requested(tool_name, params, result_text)

    result_size = len(result_text.encode("utf-8"))
    if result_size <= STDOUT_RESULT_MAX_BYTES:
        return result_text

    artifact_path = write_result_artifact(results_dir, command_id, tool_name, result_text)
    payload = try_parse_json(result_text)

    summary = {
        "status": payload.get("status") if isinstance(payload, dict) else "success",
        "id": payload.get("id") if isinstance(payload, dict) else command_id,
        "timestamp": payload.get("timestamp") if isinstance(payload, dict) else int(time.time() * 1000),
        "message": f"结果过大，已写入 {artifact_path}。",
        "truncated": True,
        "artifactPath": artifact_path,
        "originalBytes": result_size,
    }

    if tool_name == "console-get-logs":
        message = payload.get("message") if isinstance(payload, dict) else None
        parsed_message = try_parse_json(message) if isinstance(message, str) else message
        if isinstance(parsed_message, list):
            summary["logCount"] = len(parsed_message)
            summary["logPreview"] = build_console_log_preview(parsed_message)

    return json.dumps(summary, ensure_ascii=False, separators=(",", ":"))


def try_read_deferred_result(initial_result, results_dir):
    initial_payload = try_parse_json(initial_result)
    if not isinstance(initial_payload, dict):
        return initial_result

    message_payload = try_parse_json(initial_payload.get("message"))
    if not isinstance(message_payload, dict):
        return initial_result

    if message_payload.get("responseStatus") != "Processing":
        return initial_result

    request_id = message_payload.get("requestID")
    if not isinstance(request_id, str) or not request_id:
        return initial_result

    deferred_result_file = os.path.join(results_dir, f"{request_id}.json")
    deferred_result = wait_for_result(deferred_result_file, ASYNC_TIMEOUT_SECONDS)
    if deferred_result is None:
        error_exit(
            f"Timeout after {ASYNC_TIMEOUT_SECONDS}s waiting for deferred Unity response "
            f"(requestID: {request_id})"
        )

    cleanup_file(deferred_result_file)
    return deferred_result


def read_bridge_result_payload(result_text):
    payload = try_parse_json(result_text)
    if not isinstance(payload, dict):
        error_exit("Failed to parse Unity Bridge result payload.")

    message = payload.get("message")
    parsed_message = try_parse_json(message) if isinstance(message, str) else message
    return payload, parsed_message


def normalize_scene_path(path):
    if not isinstance(path, str):
        return ""

    return path.replace("\\", "/").strip()


def is_generated_scene_path(path):
    normalized_path = normalize_scene_path(path)
    if not normalized_path:
        return False

    if normalized_path in GENERATED_SCENE_EXACT_PATHS:
        return True

    return any(normalized_path.startswith(prefix) for prefix in GENERATED_SCENE_PATH_PREFIXES)


def is_recovery_scene_path(path):
    normalized_path = normalize_scene_path(path)
    if not normalized_path:
        return False

    return any(normalized_path.startswith(prefix) for prefix in RECOVERY_SCENE_PATH_PREFIXES)


def is_editor_state_settled(state, target_is_playing, target_is_paused):
    if not isinstance(state, dict):
        return False

    if bool(state.get("isPlaying")) != target_is_playing:
        return False

    if bool(state.get("isPaused")) != target_is_paused:
        return False

    if bool(state.get("isCompiling")) or bool(state.get("isUpdating")):
        return False

    if not target_is_playing and bool(state.get("isPlayingOrWillChangePlaymode")):
        return False

    return True


def build_settled_editor_state_result(source_payload, editor_state):
    settled_payload = dict(source_payload) if isinstance(source_payload, dict) else {}
    settled_payload["message"] = json.dumps(editor_state, ensure_ascii=False, separators=(",", ":"))
    settled_payload["timestamp"] = int(time.time() * 1000)
    return json.dumps(settled_payload, ensure_ascii=False, separators=(",", ":"))


def settle_editor_application_state_result(result_text, params, bridge_dir, commands_dir, results_dir):
    source_payload, initial_state = read_bridge_result_payload(result_text)
    target_is_playing = bool(params.get("isPlaying", False))
    target_is_paused = bool(params.get("isPaused", False))

    if is_editor_state_settled(initial_state, target_is_playing, target_is_paused):
        return build_settled_editor_state_result(source_payload, initial_state)

    heartbeat_before_settle = read_heartbeat_timestamp(bridge_dir, fatal=False)
    if heartbeat_before_settle is not None:
        wait_for_heartbeat_steps(
            bridge_dir,
            heartbeat_before_settle,
            EDITOR_SET_STATE_SETTLE_HEARTBEAT_STEPS,
            EDITOR_SET_STATE_SETTLE_HEARTBEAT_TIMEOUT_SECONDS,
        )

    deadline = time.time() + EDITOR_SET_STATE_SETTLE_TIMEOUT_SECONDS
    last_observed_state = initial_state if isinstance(initial_state, dict) else None
    last_error = None

    while time.time() < deadline:
        polled_result, poll_error = try_send_unity_command(
            commands_dir,
            results_dir,
            "editor-application-get-state",
            {},
            timeout_seconds=EDITOR_SET_STATE_GET_STATE_TIMEOUT_SECONDS,
        )
        if polled_result is not None:
            polled_payload, polled_state = read_bridge_result_payload(polled_result)
            if polled_payload.get("status") == "success" and isinstance(polled_state, dict):
                last_observed_state = polled_state
                if is_editor_state_settled(polled_state, target_is_playing, target_is_paused):
                    return build_settled_editor_state_result(source_payload, polled_state)
        else:
            last_error = poll_error

        time.sleep(POLL_INTERVAL)

    if isinstance(last_observed_state, dict):
        error_exit(
            "editor-application-set-state 未在预期时间内收敛到目标状态。"
            f"\nTarget: isPlaying={target_is_playing}, isPaused={target_is_paused}"
            f"\nLast observed: {json.dumps(last_observed_state, ensure_ascii=False, separators=(',', ':'))}"
        )

    error_exit(
        "editor-application-set-state 未在预期时间内拿到可用的最终状态回读。"
        f"\nTarget: isPlaying={target_is_playing}, isPaused={target_is_paused}"
        f"\nLast error: {last_error or 'none'}"
    )


def send_unity_command(commands_dir, results_dir, tool_name, params, timeout_seconds=TIMEOUT_SECONDS):
    command_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
    command_file = os.path.join(commands_dir, f"{command_id}.json")
    result_file = os.path.join(results_dir, f"{command_id}.json")
    command = {
        "id": command_id,
        "tool": tool_name,
        "params": params,
    }

    try:
        dismiss_generated_scene_save_dialog_if_present()
        write_atomic(command_file, json.dumps(command))
        result = wait_for_result(result_file, timeout_seconds)
        if result is None and os.path.exists(command_file) and not os.path.exists(result_file):
            if dismiss_generated_scene_save_dialog_if_present():
                result = wait_for_result(result_file, timeout_seconds)

        if result is None:
            cleanup_file(command_file)
            error_exit(build_timeout_diagnosis(command_file, result_file, tool_name, timeout_seconds))

        return try_read_deferred_result(result, results_dir)
    finally:
        cleanup_file(result_file)


def get_open_scene_summary(commands_dir, results_dir):
    result_text = send_unity_command(
        commands_dir,
        results_dir,
        "scene-list-opened",
        {},
    )
    payload, parsed_message = read_bridge_result_payload(result_text)
    if payload.get("status") != "success":
        error_exit(f"Failed to inspect opened Unity scenes: {payload.get('message')}")

    if not isinstance(parsed_message, list):
        return []

    return parsed_message


def is_formal_scene_disk_clean(project_root, scene_path):
    normalized = normalize_project_path(scene_path)
    if not normalized:
        return False

    scene_file = os.path.join(project_root, normalized.replace("/", os.sep))
    meta_file = f"{scene_file}.meta"
    if not os.path.exists(scene_file) or not os.path.exists(meta_file):
        return False

    import subprocess

    command = [
        "git",
        "-C",
        project_root,
        "diff",
        "--quiet",
        "--",
        normalized,
        f"{normalized}.meta",
    ]
    completed = subprocess.run(command, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    return completed.returncode == 0


def reload_formal_scenes_from_disk(commands_dir, results_dir, scene_paths):
    if not scene_paths:
        return

    escaped_paths = ", ".join(
        json.dumps(normalize_project_path(path), ensure_ascii=False) for path in scene_paths
    )
    csharp_code = f"""
using System;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

public class Script
{{
    private static readonly string[] ScenePaths = new[] {{ {escaped_paths} }};

    public static object Main()
    {{
        if (ScenePaths.Length == 0)
        {{
            return "no-formal-scenes-reloaded";
        }}

        Scene reopenedScene = EditorSceneManager.OpenScene(ScenePaths[0], OpenSceneMode.Single);
        if (!reopenedScene.IsValid())
        {{
            throw new InvalidOperationException($"Failed to reopen formal scene from disk: {{ScenePaths[0]}}");
        }}

        for (int i = 1; i < ScenePaths.Length; i++)
        {{
            Scene additiveScene = EditorSceneManager.OpenScene(ScenePaths[i], OpenSceneMode.Additive);
            if (!additiveScene.IsValid())
            {{
                throw new InvalidOperationException($"Failed to reopen formal scene additively from disk: {{ScenePaths[i]}}");
            }}
        }}

        return "reloaded-formal-scenes-from-disk";
    }}
}}
""".strip()

    result_text = send_unity_command(
        commands_dir,
        results_dir,
        "script-execute",
        {"csharpCode": csharp_code},
    )
    payload, _ = read_bridge_result_payload(result_text)
    if payload.get("status") != "success":
        error_exit(f"Failed to reload formal Unity scenes from disk: {payload.get('message')}")


def get_dirty_formal_open_scenes(commands_dir, results_dir):
    opened_scenes = get_open_scene_summary(commands_dir, results_dir)
    dirty_formal_scenes = []
    for scene_info in opened_scenes:
        if not isinstance(scene_info, dict):
            continue

        if not bool(scene_info.get("isDirty")):
            continue

        scene_path = normalize_scene_path(scene_info.get("path"))
        if is_generated_scene_path(scene_path) or is_recovery_scene_path(scene_path):
            continue

        dirty_formal_scenes.append(scene_info)

    return dirty_formal_scenes


def should_auto_save_formal_scenes_before_scene_open(tool_name, unity_params):
    if tool_name != "scene-open":
        return False

    load_scene_mode = unity_params.get("loadSceneMode")
    if load_scene_mode is None:
        return True

    if isinstance(load_scene_mode, str):
        normalized_mode = load_scene_mode.strip().lower()
        return normalized_mode in {"single", "openscenemode.single", "0"}

    if isinstance(load_scene_mode, int):
        return load_scene_mode == 0

    return False


def should_auto_save_formal_scenes_for_owned_scene_lock(tool_name, commands_dir, wrapper_params):
    if tool_name in {SCENE_LOCK_TOOL_STATUS, SCENE_LOCK_TOOL_ACQUIRE, SCENE_LOCK_TOOL_RELEASE, "scene-save"}:
        return False

    if not isinstance(wrapper_params, dict):
        return False

    token = wrapper_params.get(BRIDGE_SCENE_LOCK_TOKEN_PARAM)
    if not isinstance(token, str) or not token.strip():
        return False

    bridge_dir = os.path.dirname(commands_dir)
    ensure_owned_scene_lock(get_scene_lock_path(bridge_dir), token.strip())
    return True


def save_opened_formal_scenes(commands_dir, results_dir, scene_infos):
    if not scene_infos:
        return

    for scene_info in scene_infos:
        scene_name = scene_info.get("name")
        scene_path = normalize_project_path(scene_info.get("path"))
        if not scene_name:
            error_exit(f"AIBridge 无法自动保存正式场景：缺少 scene name。Scene path: {scene_path or '<unknown>'}")

        result_text = send_unity_command(
            commands_dir,
            results_dir,
            "scene-save",
            {"openedSceneName": scene_name},
        )
        payload, _ = read_bridge_result_payload(result_text)
        if payload.get("status") != "success":
            error_exit(f"Failed to save formal Unity scene '{scene_name}': {payload.get('message')}")

    remaining_dirty_formal_scenes = get_dirty_formal_open_scenes(commands_dir, results_dir)
    if remaining_dirty_formal_scenes:
        scene_lines = "\n".join(format_dirty_scene_label(scene_info) for scene_info in remaining_dirty_formal_scenes)
        error_exit(
            "AIBridge 已尝试在切场景前自动保存正式场景，但保存后仍存在 dirty 正式场景。"
            f"\nDirty scenes:\n{scene_lines}"
        )


def fail_if_opened_formal_scene_is_dirty(tool_name, commands_dir, results_dir, project_root=None, wrapper_params=None):
    if tool_name not in SCENE_LOCK_PROTECTED_TOOLS:
        return

    if tool_name == "scene-save":
        return

    wrapper_params = wrapper_params or {}
    unity_params = wrapper_params.get("_unityParams") if isinstance(wrapper_params, dict) else None
    if not isinstance(unity_params, dict):
        unity_params = {}

    dirty_formal_scenes = get_dirty_formal_open_scenes(commands_dir, results_dir)

    if not dirty_formal_scenes:
        return

    if should_auto_save_formal_scenes_before_scene_open(tool_name, unity_params):
        info_stderr(
            "AIBridge 检测到切场景前存在 dirty 正式场景；为避免 Unity 保存弹窗阻塞，先自动保存当前已打开正式场景。"
        )
        save_opened_formal_scenes(commands_dir, results_dir, dirty_formal_scenes)
        return

    if should_auto_save_formal_scenes_for_owned_scene_lock(tool_name, commands_dir, wrapper_params):
        info_stderr(
            "AIBridge 检测到当前命令已显式持有 scene lock，且正式场景仍是 dirty；"
            " 视为同一条自动化流程内的正式改动，先自动保存当前正式场景，再继续执行后续命令。"
        )
        save_opened_formal_scenes(commands_dir, results_dir, dirty_formal_scenes)
        return

    recovery_mode = parse_formal_scene_recovery_mode(wrapper_params.get(BRIDGE_FORMAL_SCENE_RECOVERY_MODE_PARAM))
    if recovery_mode == FORMAL_SCENE_RECOVERY_MODE_RELOAD_IF_DISK_CLEAN:
        requested_scene_paths = parse_formal_scene_recovery_scene_paths(
            wrapper_params.get(BRIDGE_FORMAL_SCENE_RECOVERY_SCENES_PARAM)
        )
        dirty_scene_paths = [normalize_project_path(scene_info.get("path")) for scene_info in dirty_formal_scenes]
        if requested_scene_paths and dirty_scene_paths == requested_scene_paths:
            if project_root and all(is_formal_scene_disk_clean(project_root, scene_path) for scene_path in dirty_scene_paths):
                info_stderr(
                    "AIBridge 检测到正式场景 dirty，但对应磁盘场景文件未改，按显式恢复策略自动从磁盘重开正式场景。"
                )
                reload_formal_scenes_from_disk(commands_dir, results_dir, dirty_scene_paths)
                reopened_scenes = get_open_scene_summary(commands_dir, results_dir)
                if all(
                    isinstance(scene_info, dict) and not bool(scene_info.get("isDirty"))
                    for scene_info in reopened_scenes
                    if normalize_project_path(scene_info.get("path")) in dirty_scene_paths
                ):
                    return

    scene_lines = "\n".join(format_dirty_scene_label(scene_info) for scene_info in dirty_formal_scenes)
    error_exit(
        "AIBridge 在发出写操作型 Unity 命令前，已通过 scene-list-opened 发现正式场景仍是 dirty。"
        " 这种情况下继续自动化，最常见结果就是卡在“场景磁盘已变化 / 是否保存”弹窗。"
        f"\nTool: {tool_name}\nDirty scenes:\n{scene_lines}"
        "\nNext action: 先由人确认这些正式场景该保存还是丢弃；在恢复为非 dirty 前，AIBridge 只允许只读取证。"
    )


def try_send_unity_command(commands_dir, results_dir, tool_name, params, timeout_seconds=TIMEOUT_SECONDS):
    command_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"
    command_file = os.path.join(commands_dir, f"{command_id}.json")
    result_file = os.path.join(results_dir, f"{command_id}.json")
    command = {
        "id": command_id,
        "tool": tool_name,
        "params": params,
    }

    try:
        dismiss_generated_scene_save_dialog_if_present()
        write_atomic(command_file, json.dumps(command))
        result = wait_for_result(result_file, timeout_seconds)
        if result is None and os.path.exists(command_file) and not os.path.exists(result_file):
            if dismiss_generated_scene_save_dialog_if_present():
                result = wait_for_result(result_file, timeout_seconds)

        if result is None:
            cleanup_file(command_file)
            return None, build_timeout_diagnosis(command_file, result_file, tool_name, timeout_seconds)

        return try_read_deferred_result(result, results_dir), None
    finally:
        cleanup_file(result_file)


def get_scene_dirty_summary(commands_dir, results_dir):
    csharp_code = """
using System;
using System.Collections.Generic;
using UnityEngine;
using UnityEngine.SceneManagement;

public class Script
{
    private const string GeneratedTestScenesDirectory = "Assets/Scenes/TestScenes/";
    private const string PlayableScenePath = "Assets/Scenes/Gameplay/Scene_PlayableSwordmaster.unity";
    private const string RecoveryScenesDirectory = "Assets/_Recovery/";
    private const string BackupScenesDirectory = "Temp/__Backupscenes/";

    [Serializable]
    private sealed class DirtySceneInfo
    {
        public string path;
        public string name;
        public bool isGenerated;
        public bool isRecovery;
    }

    [Serializable]
    private sealed class ResultPayload
    {
        public DirtySceneInfo[] dirtyScenes;
    }

    private static string NormalizeProjectPath(string path)
    {
        return string.IsNullOrWhiteSpace(path) ? string.Empty : path.Replace('\\\\', '/');
    }

    private static bool IsGeneratedScenePath(string scenePath)
    {
        string normalizedPath = NormalizeProjectPath(scenePath);
        return string.Equals(normalizedPath, PlayableScenePath, StringComparison.Ordinal)
            || normalizedPath.StartsWith(GeneratedTestScenesDirectory, StringComparison.Ordinal);
    }

    private static bool IsRecoveryScenePath(string scenePath)
    {
        string normalizedPath = NormalizeProjectPath(scenePath);
        return normalizedPath.StartsWith(RecoveryScenesDirectory, StringComparison.Ordinal)
            || normalizedPath.StartsWith(BackupScenesDirectory, StringComparison.Ordinal);
    }

    public static object Main()
    {
        List<DirtySceneInfo> dirtyScenes = new();
        for (int i = 0; i < SceneManager.sceneCount; i++)
        {
            Scene scene = SceneManager.GetSceneAt(i);
            if (!scene.IsValid() || !scene.isDirty)
            {
                continue;
            }

            string scenePath = scene.path ?? string.Empty;
            dirtyScenes.Add(new DirtySceneInfo
            {
                path = scenePath,
                name = scene.name ?? string.Empty,
                isGenerated = !string.IsNullOrWhiteSpace(scenePath) && IsGeneratedScenePath(scenePath),
                isRecovery = !string.IsNullOrWhiteSpace(scenePath) && IsRecoveryScenePath(scenePath)
            });
        }

        return JsonUtility.ToJson(new ResultPayload
        {
            dirtyScenes = dirtyScenes.ToArray()
        });
    }
}
""".strip()
    result_text = send_unity_command(
        commands_dir,
        results_dir,
        "script-execute",
        {"csharpCode": csharp_code},
    )
    payload, parsed_message = read_bridge_result_payload(result_text)
    if payload.get("status") != "success":
        error_exit(f"Failed to inspect Unity dirty scenes: {payload.get('message')}")

    if isinstance(parsed_message, dict):
        summary = parsed_message
    elif isinstance(parsed_message, str):
        summary = try_parse_json(parsed_message)
        if not isinstance(summary, dict):
            error_exit("Failed to parse Unity dirty scene summary JSON.")
    else:
        error_exit("Unity dirty scene summary returned an unsupported payload shape.")

    dirty_scenes = summary.get("dirtyScenes")
    if not isinstance(dirty_scenes, list):
        return {"dirtyScenes": []}

    return {"dirtyScenes": dirty_scenes}


def run_recovery_scene_dirty_cleanup(commands_dir, results_dir):
    csharp_code = """
using System;
using System.Collections.Generic;
using System.IO;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

public class Script
{
    private const string RecoveryScenesDirectory = "Assets/_Recovery/";
    private const string BackupScenesDirectory = "Temp/__Backupscenes/";
    private const string DefaultSafeScenePath = "Assets/Scenes/SampleScene.unity";

    private static string NormalizeProjectPath(string path)
    {
        return string.IsNullOrWhiteSpace(path) ? string.Empty : path.Replace('\\\\', '/');
    }

    private static bool IsRecoveryScenePath(string scenePath)
    {
        string normalizedPath = NormalizeProjectPath(scenePath);
        return normalizedPath.StartsWith(RecoveryScenesDirectory, StringComparison.Ordinal)
            || normalizedPath.StartsWith(BackupScenesDirectory, StringComparison.Ordinal);
    }

    public static object Main()
    {
        List<string> recoveryScenePaths = new();
        List<string> safeScenePaths = new();
        string activeScenePath = string.Empty;
        string normalizedActiveScenePath = NormalizeProjectPath(SceneManager.GetActiveScene().path);

        for (int i = 0; i < SceneManager.sceneCount; i++)
        {
            Scene scene = SceneManager.GetSceneAt(i);
            if (!scene.IsValid() || !scene.isLoaded)
            {
                continue;
            }

            string normalizedScenePath = NormalizeProjectPath(scene.path);
            if (string.IsNullOrWhiteSpace(normalizedScenePath))
            {
                continue;
            }

            if (IsRecoveryScenePath(normalizedScenePath))
            {
                recoveryScenePaths.Add(normalizedScenePath);
                continue;
            }

            safeScenePaths.Add(normalizedScenePath);
            if (string.Equals(normalizedScenePath, normalizedActiveScenePath, StringComparison.Ordinal))
            {
                activeScenePath = normalizedScenePath;
            }
        }

        if (recoveryScenePaths.Count == 0)
        {
            return "no-recovery-scenes-reloaded";
        }

        if (safeScenePaths.Count == 0)
        {
            if (!File.Exists(DefaultSafeScenePath))
            {
                throw new InvalidOperationException($"No safe non-recovery scene is loaded and fallback scene does not exist: {DefaultSafeScenePath}");
            }

            safeScenePaths.Add(DefaultSafeScenePath);
            activeScenePath = DefaultSafeScenePath;
        }

        Scene reopenedScene = EditorSceneManager.OpenScene(safeScenePaths[0], OpenSceneMode.Single);
        if (!reopenedScene.IsValid())
        {
            throw new InvalidOperationException($"Failed to reopen safe scene while discarding recovery scenes: {safeScenePaths[0]}");
        }

        for (int i = 1; i < safeScenePaths.Count; i++)
        {
            Scene additiveScene = EditorSceneManager.OpenScene(safeScenePaths[i], OpenSceneMode.Additive);
            if (!additiveScene.IsValid())
            {
                throw new InvalidOperationException($"Failed to reopen safe scene additively while discarding recovery scenes: {safeScenePaths[i]}");
            }
        }

        if (!string.IsNullOrWhiteSpace(activeScenePath))
        {
            string normalizedTargetPath = NormalizeProjectPath(activeScenePath);
            for (int i = 0; i < SceneManager.sceneCount; i++)
            {
                Scene scene = SceneManager.GetSceneAt(i);
                if (!scene.IsValid()
                    || !scene.isLoaded
                    || !string.Equals(NormalizeProjectPath(scene.path), normalizedTargetPath, StringComparison.Ordinal))
                {
                    continue;
                }

                EditorSceneManager.SetActiveScene(scene);
                break;
            }
        }

        return "reloaded-safe-scenes-and-discarded-recovery-scenes";
    }
}
""".strip()
    result_text = send_unity_command(
        commands_dir,
        results_dir,
        "script-execute",
        {"csharpCode": csharp_code},
    )
    payload, _ = read_bridge_result_payload(result_text)
    if payload.get("status") != "success":
        error_exit(f"Failed to cleanup Unity dirty recovery scenes: {payload.get('message')}")


def run_generated_scene_dirty_cleanup(commands_dir, results_dir, policy):
    if policy == "save-generated":
        csharp_code = """
using System;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

public class Script
{
    private const string GeneratedTestScenesDirectory = "Assets/Scenes/TestScenes/";
    private const string PlayableScenePath = "Assets/Scenes/Gameplay/Scene_PlayableSwordmaster.unity";

    private static string NormalizeProjectPath(string path)
    {
        return string.IsNullOrWhiteSpace(path) ? string.Empty : path.Replace('\\\\', '/');
    }

    private static bool IsGeneratedScenePath(string scenePath)
    {
        string normalizedPath = NormalizeProjectPath(scenePath);
        return string.Equals(normalizedPath, PlayableScenePath, StringComparison.Ordinal)
            || normalizedPath.StartsWith(GeneratedTestScenesDirectory, StringComparison.Ordinal);
    }

    public static object Main()
    {
        for (int i = 0; i < SceneManager.sceneCount; i++)
        {
            Scene scene = SceneManager.GetSceneAt(i);
            if (!scene.IsValid() || !scene.isLoaded || !scene.isDirty || !IsGeneratedScenePath(scene.path))
            {
                continue;
            }

            if (!EditorSceneManager.SaveScene(scene, scene.path))
            {
                throw new InvalidOperationException($"Failed to save generated scene: {scene.path}");
            }
        }

        return "saved-generated-scenes";
    }
}
""".strip()
    elif policy == "discard-generated":
        csharp_code = """
using System;
using System.Collections.Generic;
using UnityEditor.SceneManagement;
using UnityEngine.SceneManagement;

public class Script
{
    private const string GeneratedTestScenesDirectory = "Assets/Scenes/TestScenes/";
    private const string PlayableScenePath = "Assets/Scenes/Gameplay/Scene_PlayableSwordmaster.unity";

    private static string NormalizeProjectPath(string path)
    {
        return string.IsNullOrWhiteSpace(path) ? string.Empty : path.Replace('\\\\', '/');
    }

    private static bool IsGeneratedScenePath(string scenePath)
    {
        string normalizedPath = NormalizeProjectPath(scenePath);
        return string.Equals(normalizedPath, PlayableScenePath, StringComparison.Ordinal)
            || normalizedPath.StartsWith(GeneratedTestScenesDirectory, StringComparison.Ordinal);
    }

    public static object Main()
    {
        List<string> scenePaths = new();
        string activeScenePath = string.Empty;
        string normalizedActiveScenePath = NormalizeProjectPath(SceneManager.GetActiveScene().path);

        for (int i = 0; i < SceneManager.sceneCount; i++)
        {
            Scene scene = SceneManager.GetSceneAt(i);
            if (!scene.IsValid() || !scene.isLoaded)
            {
                continue;
            }

            string normalizedScenePath = NormalizeProjectPath(scene.path);
            if (string.IsNullOrWhiteSpace(normalizedScenePath))
            {
                return "no-generated-scenes-reloaded";
            }

            if (!IsGeneratedScenePath(normalizedScenePath))
            {
                return "no-generated-scenes-reloaded";
            }

            scenePaths.Add(normalizedScenePath);
            if (string.Equals(normalizedScenePath, normalizedActiveScenePath, StringComparison.Ordinal))
            {
                activeScenePath = normalizedScenePath;
            }
        }

        if (scenePaths.Count == 0)
        {
            return "no-generated-scenes-reloaded";
        }

        Scene reopenedScene = EditorSceneManager.OpenScene(scenePaths[0], OpenSceneMode.Single);
        if (!reopenedScene.IsValid())
        {
            throw new InvalidOperationException($"Failed to reopen generated scene: {scenePaths[0]}");
        }

        for (int i = 1; i < scenePaths.Count; i++)
        {
            Scene additiveScene = EditorSceneManager.OpenScene(scenePaths[i], OpenSceneMode.Additive);
            if (!additiveScene.IsValid())
            {
                throw new InvalidOperationException($"Failed to reopen generated scene additively: {scenePaths[i]}");
            }
        }

        if (!string.IsNullOrWhiteSpace(activeScenePath))
        {
            string normalizedTargetPath = NormalizeProjectPath(activeScenePath);
            for (int i = 0; i < SceneManager.sceneCount; i++)
            {
                Scene scene = SceneManager.GetSceneAt(i);
                if (!scene.IsValid()
                    || !scene.isLoaded
                    || !string.Equals(NormalizeProjectPath(scene.path), normalizedTargetPath, StringComparison.Ordinal))
                {
                    continue;
                }

                EditorSceneManager.SetActiveScene(scene);
                break;
            }
        }

        return "reloaded-generated-scenes";
    }
}
""".strip()
    else:
        error_exit(f"Unsupported generated scene dirty cleanup policy: {policy}")

    result_text = send_unity_command(
        commands_dir,
        results_dir,
        "script-execute",
        {"csharpCode": csharp_code},
    )
    payload, _ = read_bridge_result_payload(result_text)
    if payload.get("status") != "success":
        error_exit(f"Failed to cleanup Unity dirty generated scenes: {payload.get('message')}")


def format_dirty_scene_label(scene_info):
    path = scene_info.get("path") if isinstance(scene_info, dict) else None
    name = scene_info.get("name") if isinstance(scene_info, dict) else None
    label = path if isinstance(path, str) and path.strip() else "<untitled>"
    if isinstance(name, str) and name.strip() and name.strip() != label:
        return f"{label} ({name.strip()})"
    return label


def split_dirty_scenes(dirty_scenes):
    generated_dirty_scenes = []
    recovery_dirty_scenes = []
    non_generated_dirty_scenes = []
    for scene_info in dirty_scenes:
        if isinstance(scene_info, dict) and scene_info.get("isGenerated"):
            generated_dirty_scenes.append(scene_info)
        elif isinstance(scene_info, dict) and scene_info.get("isRecovery"):
            recovery_dirty_scenes.append(scene_info)
        else:
            non_generated_dirty_scenes.append(scene_info)

    return generated_dirty_scenes, recovery_dirty_scenes, non_generated_dirty_scenes


def ensure_scene_dirty_state_clean(tool_name, policy, commands_dir, results_dir, phase_label):
    if tool_name == "scene-save" and phase_label == "执行前":
        return

    summary = get_scene_dirty_summary(commands_dir, results_dir)
    dirty_scenes = summary.get("dirtyScenes", [])
    if not dirty_scenes:
        return

    generated_dirty_scenes, recovery_dirty_scenes, non_generated_dirty_scenes = split_dirty_scenes(dirty_scenes)

    if non_generated_dirty_scenes:
        scene_lines = "\n".join(format_dirty_scene_label(scene_info) for scene_info in non_generated_dirty_scenes)
        error_exit(
            f"AIBridge 命令{phase_label}检测到非生成脏场景；Bridge 不会擅自保存或丢弃用户场景，"
            "也不会在这种状态下继续执行写操作型 Unity 命令。"
            " 这种状态继续自动化，通常会把 Unity 推进到“场景磁盘已变化 / 是否保存 / 恢复备份场景”弹窗链。"
            f"\nTool: {tool_name}\nPolicy: {policy}\nDirty scenes:\n{scene_lines}"
            "\nNext action: 先由人确认这些场景该保存还是丢弃；在场景恢复为非 dirty 前，AIBridge 只允许只读取证。"
        )

    if policy == "ignore":
        return

    if recovery_dirty_scenes:
        run_recovery_scene_dirty_cleanup(commands_dir, results_dir)

    if generated_dirty_scenes and policy in {"save-generated", "discard-generated"}:
        run_generated_scene_dirty_cleanup(commands_dir, results_dir, policy)

    post_cleanup_summary = get_scene_dirty_summary(commands_dir, results_dir)
    remaining_dirty_scenes = post_cleanup_summary.get("dirtyScenes", [])
    if remaining_dirty_scenes:
        scene_lines = "\n".join(format_dirty_scene_label(scene_info) for scene_info in remaining_dirty_scenes)
        error_exit(
            f"AIBridge 命令{phase_label}清理后仍存在脏场景。"
            f"\nTool: {tool_name}\nPolicy: {policy}\nDirty scenes:\n{scene_lines}"
        )


def handle_pre_command_scene_cleanup(tool_name, policy, commands_dir, results_dir):
    ensure_scene_dirty_state_clean(tool_name, policy, commands_dir, results_dir, "执行前")


def handle_post_command_scene_cleanup(tool_name, policy, commands_dir, results_dir):
    if tool_name == "editor-application-set-state":
        # PlayMode 切换本身不应被 generic dirty-summary 探针再次打断；
        # 执行前守卫已覆盖保存弹窗风险，执行后再立刻用 script-execute 回读 dirty scene
        # 在 Unity 进入/退出 PlayMode 的窗口期容易出现“命令已消费但无结果”的假失败。
        return

    ensure_scene_dirty_state_clean(tool_name, policy, commands_dir, results_dir, "收尾后")


def attempt_failure_scene_cleanup(tool_name, policy, commands_dir, results_dir):
    if tool_name == "editor-application-set-state":
        return

    if policy not in {"save-generated", "discard-generated"}:
        return

    try:
        dismiss_generated_scene_save_dialog_if_present()
        ensure_scene_dirty_state_clean(tool_name, policy, commands_dir, results_dir, "失败后补收尾")
    except SystemExit:
        warning_stderr(
            f"AIBridge 命令失败后已尝试按 {policy} 收尾已知生成场景，但未能确认场景栈已清洁；"
            "请检查当前 Unity Editor 的打开场景与 dirty 状态。"
        )
    except Exception as ex:
        warning_stderr(
            f"AIBridge 命令失败后尝试收尾已知生成场景时出现异常：{ex}"
        )


def build_timeout_diagnosis(command_file, result_file, tool_name, timeout_seconds):
    command_exists = os.path.exists(command_file)
    result_exists = os.path.exists(result_file)

    if command_exists and not result_exists:
        return (
            f"Timeout after {timeout_seconds}s waiting for Unity response (tool: {tool_name}). "
            "The command file was never consumed from Temp/UnityBridge/commands, "
            "which indicates UnityAiBridge.FileBridgePoller is not polling commands in the current Editor session."
        )

    if not command_exists and not result_exists:
        return (
            f"Timeout after {timeout_seconds}s waiting for Unity response (tool: {tool_name}). "
            "The command file was consumed but no result file was written within the grace window."
        )

    return f"Timeout after {timeout_seconds}s waiting for Unity response (tool: {tool_name})"


# ─────────────────────────────────────────
# 主流程
# ─────────────────────────────────────────

def main():
    if len(sys.argv) < 2:
        error_exit("Usage: bridge.py <tool-name> [json-params]")

    tool_name = sys.argv[1]
    params_str = sys.argv[2] if len(sys.argv) > 2 else "{}"

    # 验证 JSON 参数
    try:
        params = json.loads(params_str)
    except json.JSONDecodeError as e:
        error_exit(f"Invalid JSON params: {e}")

    project_root = get_project_root()
    bridge_dir = get_bridge_dir(project_root)
    commands_dir = os.path.join(bridge_dir, "commands")
    results_dir = os.path.join(bridge_dir, "results")
    lock_file = os.path.join(bridge_dir, ".cli.lock")
    scene_lock_file = get_scene_lock_path(bridge_dir)

    if handle_scene_lock_tool(tool_name, params, bridge_dir):
        return

    params, wrapper_params = split_bridge_wrapper_params(params)
    wrapper_params["_unityParams"] = params
    scene_dirty_policy = resolve_scene_dirty_policy(tool_name, params, wrapper_params)

    # 生成唯一命令 ID
    command_id = f"{int(time.time())}-{uuid.uuid4().hex[:8]}"

    # 构建命令 JSON
    command = {
        "id": command_id,
        "tool": tool_name,
        "params": params
    }

    # 确保目录存在
    os.makedirs(commands_dir, exist_ok=True)
    os.makedirs(results_dir, exist_ok=True)
    command_file = os.path.join(commands_dir, f"{command_id}.json")
    result_file = os.path.join(results_dir, f"{command_id}.json")
    lock_acquired = False
    scene_lock_context = None
    command_dispatched = False
    audit_entry = {
        "timestamp": int(time.time() * 1000),
        "commandId": command_id,
        "tool": tool_name,
        "sceneDirtyPolicy": scene_dirty_policy,
        "wrapperParams": sanitize_audit_value(
            {
                key: value
                for key, value in wrapper_params.items()
                if key != "_unityParams"
            }
        ),
        "unityParamsSummary": summarize_unity_params_for_audit(tool_name, params),
        "status": "pending",
    }
    try:
        scene_lock_context = acquire_scene_lock_for_command(scene_lock_file, tool_name, wrapper_params)
        acquire_cli_lock(lock_file, command_id, tool_name)
        lock_acquired = True

        dismiss_generated_scene_save_dialog_if_present()
        fail_if_blocking_unity_save_dialog()

        # 检查 Unity Editor 在线
        heartbeat_status = check_heartbeat(bridge_dir)
        audit_entry["heartbeat"] = sanitize_audit_value(heartbeat_status)
        fail_if_opened_formal_scene_is_dirty(
            tool_name,
            commands_dir,
            results_dir,
            project_root=project_root,
            wrapper_params=wrapper_params,
        )
        if should_capture_scene_dirty_audit(tool_name):
            audit_entry["preSceneDirtySummary"] = try_capture_scene_dirty_summary(commands_dir, results_dir)
        handle_pre_command_scene_cleanup(
            tool_name,
            scene_dirty_policy,
            commands_dir,
            results_dir,
        )

        # 原子写入命令文件
        write_atomic(command_file, json.dumps(command))
        command_dispatched = True

        # 轮询等待结果
        result = wait_for_result(result_file, TIMEOUT_SECONDS)
        if result is None:
            if os.path.exists(command_file) and not os.path.exists(result_file):
                if dismiss_generated_scene_save_dialog_if_present():
                    result = wait_for_result(result_file, TIMEOUT_SECONDS)
            elif not os.path.exists(command_file) and not os.path.exists(result_file):
                warning_stderr(
                    f"AIBridge 命令 {tool_name} 已被 Unity 消费，但 {TIMEOUT_SECONDS}s 内未收到结果；"
                    f"追加等待 {CONSUMED_COMMAND_GRACE_SECONDS}s 以吸收迟到回包。"
                )
                result = wait_for_consumed_command_result(
                    command_file,
                    result_file,
                    CONSUMED_COMMAND_GRACE_SECONDS,
                )

        if result is None:
            fail_if_blocking_unity_save_dialog()
            diagnosis = build_timeout_diagnosis(command_file, result_file, tool_name, TIMEOUT_SECONDS)
            cleanup_file(command_file)
            error_exit(diagnosis)

        # 读取结果
        result = try_read_deferred_result(result, results_dir)
        if tool_name == "editor-application-set-state":
            result = settle_editor_application_state_result(
                result,
                params,
                bridge_dir,
                commands_dir,
                results_dir,
            )
        if tool_name == "tests-run" and not heartbeat_status["heartbeat_stale"]:
            heartbeat_before_release = read_heartbeat_timestamp(bridge_dir, fatal=False)
            if heartbeat_before_release is not None:
                wait_for_heartbeat_steps(
                    bridge_dir,
                    heartbeat_before_release,
                    TESTS_RUN_SETTLE_HEARTBEAT_STEPS,
                    TESTS_RUN_SETTLE_TIMEOUT_SECONDS,
                )
        dismiss_generated_scene_save_dialog_if_present()
        handle_post_command_scene_cleanup(
            tool_name,
            scene_dirty_policy,
            commands_dir,
            results_dir,
        )
        if should_capture_scene_dirty_audit(tool_name):
            audit_entry["postSceneDirtySummary"] = try_capture_scene_dirty_summary(commands_dir, results_dir)
        audit_entry["status"] = extract_result_status_for_audit(result) or "success"
        audit_entry["resultSummary"] = summarize_result_for_audit(result)
        result = prepare_stdout_result(tool_name, params, result, results_dir, command_id)
        print(result)
    except SystemExit as ex:
        audit_entry["status"] = "error"
        audit_entry["error"] = truncate_audit_text(ex)
        if command_dispatched:
            attempt_failure_scene_cleanup(
                tool_name,
                scene_dirty_policy,
                commands_dir,
                results_dir,
            )
        raise
    except BaseException as ex:
        audit_entry["status"] = "error"
        audit_entry["error"] = truncate_audit_text(repr(ex))
        if command_dispatched and should_capture_scene_dirty_audit(tool_name):
            audit_entry["failureSceneDirtySummary"] = try_capture_scene_dirty_summary(commands_dir, results_dir)
        raise
    finally:
        audit_entry["finishedAt"] = int(time.time() * 1000)
        append_command_audit_entry(bridge_dir, audit_entry)
        cleanup_file(result_file)
        if lock_acquired:
            release_cli_lock(lock_file)
        if scene_lock_context and scene_lock_context.get("autoRelease"):
            token = scene_lock_context.get("lock", {}).get("token")
            if token:
                release_scene_lock(scene_lock_file, token)


if __name__ == "__main__":
    main()
