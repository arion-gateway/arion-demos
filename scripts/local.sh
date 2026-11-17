#!/usr/bin/env bash
set -euo pipefail

ROOT="$(CDPATH= cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
STATE="$ROOT/.demo"
ARION_BIN="${ARION_BIN:-$ROOT/../arion/target/debug/arion}"
ARION_CTL_BIN="${ARION_CTL_BIN:-$ROOT/../arion-ctl/apps/arion_ctl/_build/prod/rel/arion_ctl/bin/arionctl}"

export ARION_CTL_PORT=15051
export ARION_CTL_STATE_DIR="$STATE/control-state"
export RELEASE_TMP="$STATE/release-tmp"
export ERL_CRASH_DUMP="$STATE/erl_crash.dump"
export RELEASE_NODE="${RELEASE_NODE:-arion_demo_local}"
export RELEASE_COOKIE="${RELEASE_COOKIE:-arion_demo_cookie}"
export ERL_FLAGS="${ERL_FLAGS:-+S 2:2}"
export ERL_MAX_PORTS="${ERL_MAX_PORTS:-65536}"

fail() { echo "$*" >&2; exit 1; }
port_open() { (exec 3<>"/dev/tcp/127.0.0.1/$1") 2>/dev/null; }
stop_pid() {
  local file="$1" pid
  [[ -f "$file" ]] || return 0
  pid="$(tr -d '[:space:]' < "$file")"
  if [[ "$pid" =~ ^[0-9]+$ ]]; then
    kill "$pid" 2>/dev/null || true
    for _ in $(seq 1 50); do
      local stat
      stat="$(ps -p "$pid" -o stat= 2>/dev/null | tr -d '[:space:]' || true)"
      [[ -n "$stat" && "$stat" != Z* ]] || break
      sleep 0.1
    done
  fi
  rm -f "$file"
}

case "${1:-help}" in
  start)
    [[ -x "$ARION_BIN" ]] || fail "ARION_BIN not executable: $ARION_BIN"
    [[ -x "$ARION_CTL_BIN" ]] || fail "ARION_CTL_BIN not executable: $ARION_CTL_BIN"
    "$0" stop >/dev/null 2>&1 || true
    mkdir -p "$STATE/release-tmp"
    rm -rf "$STATE/control-state"

    "$ARION_CTL_BIN" serve >"$STATE/control.log" 2>&1 &
    echo $! > "$STATE/control.pid"
    for _ in $(seq 1 150); do port_open 15051 && break; sleep 0.2; done
    port_open 15051 || fail "arionctl failed to start; check .demo/control.log"

    "$ARION_BIN" --config "$ROOT/common/runtime.yaml" \
      --with-envoy-bootstrap "$ROOT/common/bootstrap.yaml" -C 1 -R 1 \
      >"$STATE/proxy.log" 2>&1 &
    echo $! > "$STATE/proxy.pid"
    echo "Started local arion-ctl (:15051) and arion proxy. Run: ./scripts/local.sh shell"
    ;;
  shell) exec "$ARION_CTL_BIN" shell ;;
  ctl) shift; exec "$ARION_CTL_BIN" "$@" ;;
  logs)
    service="${2:-proxy}"
    [[ -f "$STATE/$service.log" ]] || fail "No log at .demo/$service.log"
    tail -n 60 "$STATE/$service.log"
    ;;
  stop)
    stop_pid "$STATE/proxy.pid"
    stop_pid "$STATE/control.pid"
    echo "Stopped."
    ;;
  *)
    echo "Usage: ./scripts/local.sh start | shell | ctl ARGS... | logs [proxy|control] | stop"
    ;;
esac
