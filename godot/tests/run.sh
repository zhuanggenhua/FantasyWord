#!/usr/bin/env bash
# 迁移模块验证：当前不测试 Unity 导入或实际游玩。
set -euo pipefail
cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.."
temp_dir="$(mktemp -d)"
trap 'rm -rf -- "$temp_dir"' EXIT
export HOME="$temp_dir/home" XDG_DATA_HOME="$temp_dir/data" XDG_CONFIG_HOME="$temp_dir/config" XDG_CACHE_HOME="$temp_dir/cache"
mkdir -p "$HOME" "$XDG_DATA_HOME" "$XDG_CONFIG_HOME" "$XDG_CACHE_HOME"
editor="${GODOT:-godot}"
shopt -s nullglob
suites=(tests/test_*.gd)
if (( ${#suites[@]} == 0 )); then
    echo '缺少 Godot 测试。' >&2
    exit 1
fi
for file in "${suites[@]}"; do
    echo "== $file =="
    timeout 45s "$editor" --headless --path . --script "res://$file" 2>&1 | tee "$temp_dir/test.log"
    grep -q '^PASS ' "$temp_dir/test.log"
    if grep -Eq 'SCRIPT ERROR:|(^|[[:space:]])ERROR:' "$temp_dir/test.log"; then
        echo "检测到脚本或引擎错误：$file" >&2
        exit 1
    fi
done
