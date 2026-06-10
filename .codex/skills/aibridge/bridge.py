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
import ctypes
from ctypes import wintypes

TIMEOUT_SECONDS = 30
ASYNC_TIMEOUT_SECONDS = 300
POLL_INTERVAL = 0.1
HEARTBEAT_MAX_AGE = 10
EDITOR_LOG_RECENT_SECONDS = 120
LOCK_TIMEOUT_SECONDS = ASYNC_TIMEOUT_SECONDS + TIMEOUT_SECONDS + 30
LOCK_STALE_SECONDS = LOCK_TIMEOUT_SECONDS + 30
TESTS_RUN_SETTLE_TIMEOUT_SECONDS = 12
TESTS_RUN_SETTLE_HEARTBEAT_STEPS = 5
HEARTBEAT_READ_RETRY_COUNT = 20
HEARTBEAT_READ_RETRY_DELAY = 0.05
SCENE_LOCK_DEFAULT_TIMEOUT_SECONDS = 600
SCENE_LOCK_STALE_SECONDS = 1800

BRIDGE_SCENE_LOCK_TOKEN_PARAM = "bridgeSceneLockToken"
BRIDGE_SCENE_LOCK_MODE_PARAM = "bridgeSceneLockMode"
BRIDGE_SCENE_LOCK_TIMEOUT_PARAM = "bridgeSceneLockTimeoutSeconds"
BRIDGE_SCENE_LOCK_REASON_PARAM = "bridgeSceneLockReason"
BRIDGE_SCENE_DIRTY_POLICY_PARAM = "bridgeSceneDirtyPolicy"
BRIDGE_SCENE_LOCK_WRAPPER_PARAMS = {
    BRIDGE_SCENE_LOCK_TOKEN_PARAM,
    BRIDGE_SCENE_LOCK_MODE_PARAM,
    BRIDGE_SCENE_LOCK_TIMEOUT_PARAM,
    BRIDGE_SCENE_LOCK_REASON_PARAM,
    BRIDGE_SCENE_DIRTY_POLICY_PARAM,
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
GENERATED_SCENE_DIALOG_MARKERS = (
    "TestScene_",
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


def get_project_root():
    """从 cwd 获取项目根目录（工作目录即项目根）"""
    return os.getcwd()


def error_exit(message):
    print(json.dumps({"status": "error", "message": message}), file=sys.stderr)
    sys.exit(1)


def warning_stderr(message):
    print(json.dumps({"status": "warning", "message": message}), file=sys.stderr)


def get_bridge_dir(project_root):
    return os.path.join(project_root, "Temp", "UnityBridge")


def get_scene_lock_path(bridge_dir):
    return os.path.join(bridge_dir, ".scene.lock")


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


def dismiss_generated_scene_save_dialog_if_present():
    if not sys.platform.startswith("win"):
        return False

    unity_pid = get_unity_process_id()
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


def is_lock_stale(lock_path, stale_seconds):
    lock_info = read_lock_info(lock_path)
    if isinstance(lock_info, dict):
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


def build_scene_lock_payload(token, owner, reason):
    timestamp = time.time()
    return {
        "token": token,
        "owner": owner,
        "reason": reason,
        "pid": os.getpid(),
        "timestamp": timestamp,
    }


def write_lock_file_exclusive(lock_path, lock_payload):
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
    updated_lock_info["pid"] = os.getpid()
    updated_lock_info["timestamp"] = time.time()
    write_atomic(lock_path, json.dumps(updated_lock_info))
    return updated_lock_info


def acquire_scene_lock(lock_path, owner, reason, mode, timeout_seconds):
    start_time = time.time()

    while True:
        lock_payload = build_scene_lock_payload(
            token=uuid.uuid4().hex,
            owner=owner,
            reason=reason,
        )

        try:
            write_lock_file_exclusive(lock_path, lock_payload)
            return lock_payload
        except (FileExistsError, PermissionError):
            if is_lock_stale(lock_path, SCENE_LOCK_STALE_SECONDS):
                cleanup_file(lock_path)
                continue

            lock_info = read_lock_info(lock_path)
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
    if is_lock_stale(lock_path, SCENE_LOCK_STALE_SECONDS):
        cleanup_file(lock_path)
        error_exit("AIBridge 场景锁已过期并被清理；请重新获取 scene lock 后再继续。")

    lock_info = read_lock_info(lock_path)
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

    if is_lock_stale(lock_path, SCENE_LOCK_STALE_SECONDS):
        cleanup_file(lock_path)
        return {"released": False, "locked": False, "staleCleared": True}

    lock_info = read_lock_info(lock_path)
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
    stale = is_lock_stale(lock_path, SCENE_LOCK_STALE_SECONDS)
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
        owner = str(params.get("owner") or f"pid-{os.getpid()}").strip()
        reason = str(params.get("reason") or "AIBridge 场景端到端占用").strip()
        mode = parse_scene_lock_mode(params.get("mode"))
        timeout_seconds = parse_scene_lock_timeout(params.get("timeoutSeconds"))
        lock_payload = acquire_scene_lock(lock_path, owner, reason, mode, timeout_seconds)
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
    )
    return {
        "autoRelease": True,
        "lock": lock_payload,
    }


def acquire_cli_lock(lock_path, command_id, tool_name):
    start_time = time.time()

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
        except (FileExistsError, PermissionError):
            if is_lock_stale(lock_path, LOCK_STALE_SECONDS):
                cleanup_file(lock_path)
                continue

            elapsed = time.time() - start_time
            if elapsed >= LOCK_TIMEOUT_SECONDS:
                lock_info = read_lock_info(lock_path)
                holder = ""
                if isinstance(lock_info, dict):
                    pid = lock_info.get("pid")
                    tool = lock_info.get("tool")
                    holder = f" Lock holder pid={pid}, tool={tool}."
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
    elapsed = 0.0

    while not os.path.exists(result_file):
        time.sleep(POLL_INTERVAL)
        elapsed += POLL_INTERVAL

        if elapsed >= timeout_seconds:
            return None

    with open(result_file, "r", encoding="utf-8") as f:
        return f.read()


def try_parse_json(text):
    try:
        return json.loads(text)
    except (TypeError, json.JSONDecodeError):
        return None


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
            error_exit(build_timeout_diagnosis(command_file, result_file, tool_name))

        return try_read_deferred_result(result, results_dir)
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

    [Serializable]
    private sealed class DirtySceneInfo
    {
        public string path;
        public string name;
        public bool isGenerated;
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
                isGenerated = !string.IsNullOrWhiteSpace(scenePath) && IsGeneratedScenePath(scenePath)
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
    non_generated_dirty_scenes = []
    for scene_info in dirty_scenes:
        if isinstance(scene_info, dict) and scene_info.get("isGenerated"):
            generated_dirty_scenes.append(scene_info)
        else:
            non_generated_dirty_scenes.append(scene_info)

    return generated_dirty_scenes, non_generated_dirty_scenes


def ensure_scene_dirty_state_clean(tool_name, policy, commands_dir, results_dir, phase_label):
    if policy == "ignore":
        return

    summary = get_scene_dirty_summary(commands_dir, results_dir)
    dirty_scenes = summary.get("dirtyScenes", [])
    if not dirty_scenes:
        return

    generated_dirty_scenes, non_generated_dirty_scenes = split_dirty_scenes(dirty_scenes)

    if non_generated_dirty_scenes:
        scene_lines = "\n".join(format_dirty_scene_label(scene_info) for scene_info in non_generated_dirty_scenes)
        error_exit(
            f"AIBridge 命令{phase_label}检测到非生成脏场景；Bridge 不会擅自保存或丢弃用户场景。"
            f"\nTool: {tool_name}\nDirty scenes:\n{scene_lines}"
        )

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
    ensure_scene_dirty_state_clean(tool_name, policy, commands_dir, results_dir, "收尾后")


def attempt_failure_scene_cleanup(tool_name, policy, commands_dir, results_dir):
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


def build_timeout_diagnosis(command_file, result_file, tool_name):
    command_exists = os.path.exists(command_file)
    result_exists = os.path.exists(result_file)

    if command_exists and not result_exists:
        return (
            f"Timeout after {TIMEOUT_SECONDS}s waiting for Unity response (tool: {tool_name}). "
            "The command file was never consumed from Temp/UnityBridge/commands, "
            "which indicates UnityAiBridge.FileBridgePoller is not polling commands in the current Editor session."
        )

    if not command_exists and not result_exists:
        return (
            f"Timeout after {TIMEOUT_SECONDS}s waiting for Unity response (tool: {tool_name}). "
            "The command file was consumed but no result file was written."
        )

    return f"Timeout after {TIMEOUT_SECONDS}s waiting for Unity response (tool: {tool_name})"


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
    try:
        scene_lock_context = acquire_scene_lock_for_command(scene_lock_file, tool_name, wrapper_params)
        acquire_cli_lock(lock_file, command_id, tool_name)
        lock_acquired = True

        dismiss_generated_scene_save_dialog_if_present()

        # 检查 Unity Editor 在线
        heartbeat_status = check_heartbeat(bridge_dir)
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

        if result is None:
            diagnosis = build_timeout_diagnosis(command_file, result_file, tool_name)
            cleanup_file(command_file)
            error_exit(diagnosis)

        # 读取结果
        result = try_read_deferred_result(result, results_dir)
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
        print(result)
    except SystemExit:
        if command_dispatched:
            attempt_failure_scene_cleanup(
                tool_name,
                scene_dirty_policy,
                commands_dir,
                results_dir,
            )
        raise
    finally:
        cleanup_file(result_file)
        if lock_acquired:
            release_cli_lock(lock_file)
        if scene_lock_context and scene_lock_context.get("autoRelease"):
            token = scene_lock_context.get("lock", {}).get("token")
            if token:
                release_scene_lock(scene_lock_file, token)


if __name__ == "__main__":
    main()
