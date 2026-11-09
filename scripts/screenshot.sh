#!/usr/bin/env bash
set -euo pipefail

# NocturnalZone Astroテーマのプレビュー画像（images/screenshot.png）を再生成する。
# ローカルのAstro devサーバーとヘッドレスChromeだけで完結するため、
# 画面操作は行わず、追跡中の画像を書き換えずに--output-dirで試せる。

usage() {
    cat <<'USAGE'
Regenerate images/screenshot.png (1600x900) with the local Astro dev server and headless Chrome.

Usage:
  scripts/screenshot.sh [options]

Options:
  -o, --output-dir DIR  Output directory for screenshot.png. Default: images/
      --port PORT       Port for the Astro dev server. Default: 4322
  -h, --help            Show this help and exit.

Environment:
  CHROME  Chrome executable.
          Default: /Applications/Google Chrome.app/Contents/MacOS/Google Chrome

Requirements:
  - `npm install` has been run in the repository root.
  - Google Chrome is installed.
USAGE
}

die() {
    printf 'error: %s\n' "$*" >&2
    exit 1
}

display_path() {
    local path="$1"
    case "$path" in
    "$repo_root"/*) printf '%s\n' "${path#"$repo_root"/}" ;;
    *) printf '%s\n' "$path" ;;
    esac
}

# 撮影対象はトップページのみ。画像サイズは1600x900で固定する。
window_size="1600,900"

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
repo_root="$(cd "$script_dir/.." && pwd -P)"

output_dir="$repo_root/images"
port=4322
chrome="${CHROME:-/Applications/Google Chrome.app/Contents/MacOS/Google Chrome}"

while [ "$#" -gt 0 ]; do
    case "$1" in
    -o | --output-dir)
        [ "$#" -ge 2 ] || die "$1 requires a directory"
        output_dir="$2"
        shift 2
        ;;
    --port)
        [ "$#" -ge 2 ] || die "$1 requires a port"
        port="$2"
        shift 2
        ;;
    -h | --help)
        usage
        exit 0
        ;;
    *)
        usage >&2
        die "unknown argument: $1"
        ;;
    esac
done

[ -x "$chrome" ] || die "Chrome not found: $chrome (set CHROME to override)"
command -v npm >/dev/null 2>&1 || die "npm not found"
[ -d "$repo_root/node_modules" ] ||
    die "node_modules not found; run 'npm install' in $repo_root first"

tmp_dir=""
server_pid=""

stop_server() {
    [ -n "$server_pid" ] || return 0
    if kill -0 "$server_pid" 2>/dev/null; then
        # npmはdevサーバーを子プロセスとして起動するため、process groupごと止める。
        # 起動時と同じく独立process groupへ入れてあるので、負のpidでgroupを指定する。
        kill -- "-$server_pid" 2>/dev/null || kill "$server_pid" 2>/dev/null || true
        local waited=0
        while kill -0 "$server_pid" 2>/dev/null && [ "$waited" -lt 50 ]; do
            sleep 0.1
            waited=$((waited + 1))
        done
        kill -9 -- "-$server_pid" 2>/dev/null || true
    fi
    server_pid=""
}

cleanup() {
    local status=$?
    stop_server
    if [ -n "$tmp_dir" ] && [ -d "$tmp_dir" ]; then
        if [ -x /usr/bin/trash ]; then
            /usr/bin/trash "$tmp_dir" >/dev/null 2>&1 ||
                printf 'warning: could not move %s to Trash\n' "$tmp_dir" >&2
        else
            printf 'warning: /usr/bin/trash not found; leaving %s\n' "$tmp_dir" >&2
        fi
    fi
    return "$status"
}
trap cleanup EXIT
trap 'exit 130' INT TERM

# 到達確認はcurlで行い、固定sleepで代用しない。期限を過ぎたら失敗として扱う。
wait_for_http() {
    local url="$1" timeout="$2" start=$SECONDS
    while ! curl -fsS -o /dev/null --max-time 5 "$url" 2>/dev/null; do
        [ $((SECONDS - start)) -lt "$timeout" ] || return 1
        sleep 0.5
    done
}

tmp_dir="$(mktemp -d)"
server_log="$tmp_dir/dev-server.log"
shot="$tmp_dir/screenshot.png"

cd "$repo_root"

# 別のプロセスが同じportで応答していると、その画面を誤って撮影してしまう。
if curl -fsS -o /dev/null --max-time 2 "http://127.0.0.1:$port/" 2>/dev/null; then
    die "port $port is already in use; stop that server or pass --port"
fi

# 子プロセス出力はlogへ隔離し、stdoutには要約だけを出す。
set -m
npm run dev -- --port "$port" >"$server_log" 2>&1 &
server_pid=$!
set +m

if ! wait_for_http "http://127.0.0.1:$port/" 120; then
    printf 'error: dev server did not respond on http://127.0.0.1:%s/\n' "$port" >&2
    tail -n 40 "$server_log" >&2 || true
    exit 1
fi
# 応答したのが自分で起動したserverであることを確かめる。
kill -0 "$server_pid" 2>/dev/null || die "dev server exited; see the log above"

if ! "$chrome" --headless --disable-gpu --no-first-run --hide-scrollbars \
    --user-data-dir="$tmp_dir/chrome-profile" \
    --screenshot="$shot" --window-size="$window_size" \
    "http://127.0.0.1:$port/" >"$tmp_dir/chrome.log" 2>&1; then
    printf 'error: headless Chrome failed\n' >&2
    tail -n 20 "$tmp_dir/chrome.log" >&2 || true
    exit 1
fi

[ -s "$shot" ] || die "headless Chrome did not write $shot"

mkdir -p "$output_dir"
cp "$shot" "$output_dir/screenshot.png"

printf 'wrote %s (%s)\n' "$(display_path "$output_dir/screenshot.png")" "$window_size"
