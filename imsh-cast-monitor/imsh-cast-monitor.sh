#!/usr/bin/env bash

argv0="imsh-cast-monitor"
imshCastArgv0="imsh-cast"
wfRecorderArgv0="wf-recorder"

usage() {
cat <<EOF
$argv0 - Display a flashing circle while imsh-cast is recording.

Usage: $argv0 [pid-file] [options...]

Options:
  pid-file
    PID file to watch for an active process.
    Defaults to: \$XDG_RUNTIME_DIR/$imshCastArgv0-0.pid

  -h, --help
    Display this message.
EOF
}

fatalUser() {
cat >&2 <<EOF
Error: $1

See $argv0 --help for more information.
EOF
exit 2
}

warn() {
  printf "Warning: %s\n" "$1" >&2
}

status() {
  text="$1"; shift
  class="$1"; shift
  jq -nc \
    --arg text "$text" \
    --arg class "$class" \
    '{"text": $text, "class": [ "imsh-cast-monitor", $class]}'
}

pidFile="$XDG_RUNTIME_DIR/$imshCastArgv0-0.pid"
positional=()
ignoreOpts=
while [[ $# -gt 0 ]]; do
  case "$ignoreOpts$1" in
    -h|--help) usage; exit 0;;
    --) ignoreOpts=1;;
    -*) fatalUser "invalid option: $1";;
    *) positional+=("$1");;
  esac
done
set -- "${positional[@]}"

pidFile="${1:-$pidFile}"; shift

if [[ $# -gt 0 ]]; then
  fatalUser "extraneous positional arguments ($*)"
elif [[ -z "$pidFile" ]]; then
  fatalUser "missing pid-file argument"
fi

state=
while true; do
  text=
  class=
  [[ -e "$pidFile" ]] && pid="$(tr -d '[:space:]' <"$pidFile")" || pid=
  [[ "$pid" -gt 0 ]] && [[ -e "/proc/$pid" ]] \
    && pidArgv0="$(basename "$(tr '\0' '\n' <"/proc/$pid/cmdline" | head -n1)")" \
    || pidArgv0=

  if [[ "$pidArgv0" = "$wfRecorderArgv0" ]]; then
    state=$((!state))
    ((state)) && text=$'\uebb4' || text=$'\uebb5'
    class="recording"
  elif [[ -n "$pid" ]] || [[ -e "$pidFile" ]]; then
    warn "invalid PID file contents, this may have been caused by a previous $imshCastArgv0 crash."
    state=
    text=$'\ueabd'
    class="error"
  else
    state=
    text=""
    class="inactive"
  fi

  status "$text" "$class"

  inotifywait "$(dirname "$pidFile")" \
    --include "$(basename "$pidFile")" \
    --timeout 1 \
    --event create \
    --event delete \
    --event modify \
    >/dev/null 2>&1
done
