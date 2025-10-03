#!/usr/bin/env bash

argv0="imsh-shot"

usage() {
cat <<EOF
$argv0 - Capture and optionally upload a screenshot to an imsh server

Usage: $argv0 target [options...]

Targets:
  active
    Currently active window.

  screen
    All visible outputs.

  output
    Currently active output.

  area
    Manually select a region or window.

Options:
  -u, --upload
    Uploads the screenshot to imsh.

  -a, --api-key=key|@file|%cmd
    API key for uploading to imsh.
    Prefix with "@" to read from a file.
    Prefix with "%" to run a command.

  -e, --endpoint=url
    The imsh endpoint to upload to.
    Defaults to https://scrn.is/api/v1/upload

  -o, --output=path-pattern
    Path to write captured screenshot to. Gets passed through date and
    supports the same format strings.

  -U, --utc
    Call date with -u to use UTC for added privacy when sharing.

  -C, --copy
    Copy the captured screenshot to the clipboard. If uploading, instead
    copy the returned URL.

  -f, --freeze
    Freezes the screen before area selection.
    Only works when target is area.

  -w, --wait=n
    Wait for n seconds before taking a screenshot.

  -s, --scale=n
    Passes the -s argument to grim.

  -c, --cursor
    Include cursors in the screenshot.

  -t, --filetype=type
    Output filetype. Supports png, ppm, jpeg.
    Only png works with the -C option.
    Default: png

  -h, --help
    Display this message.
EOF
}

fatalUser() {
cat <<EOF
Error: $1

See $argv0 --help for more information.
EOF
exit 2
}

fatal() {
  printf "Error: %s\n" "$1" >&2
  exit 1
}

check() {
  err=()
  while [[ $# -gt 0 ]]; do
    msg="$1"; shift
    cond="$1"; shift
    value="$1"; shift
    [[ "$cond" -ne 0 ]] && [[ -z "$value" ]] && err+=("$msg" ", ")
  done
  if [[ ${#err[@]} -gt 0 ]]; then
    IFS=""
    fatalUser "${err[*]::${#err[@]}-1}" >&2
  fi
}

optsWithArgs=(
  -a --api-key
  -e --endpoint
  -o --output
  -w --wait
  -s --scale
  -t --filetype
)

# Preprocess options:
# Expand -fff to -f -f -f.
# Expand -kv to -k v.
# Expand --key=value to --key value.
# Stop preprocessing once -- is observed.
argv=()
ignoreOpts=
while [[ $# -gt 0 ]]; do
  case "$ignoreOpts$1" in
    --) argv+=("$1"); ignoreOpts=1;;
    --*=*)
      argv+=("${1%%=*}" "${1#*=}")
      (IFS="|"; [[ "|${optsWithArgs[*]}" = *"|${1%%=*}"* ]]) \
        || fatalUser "invalid option: $1"
      ;;
    --*) argv+=("$1");;
    -*)
      for ((i=1; i < ${#1}; ++i)); do
        argv+=("-${1:i:1}");
        if (IFS="|"; [[ "|${optsWithArgs[*]}" = *"|-${1:i:1}"* ]]) && [[ -n "${1:i+1}" ]]; then
          argv+=("${1:i+1}")
          break
        fi
      done;;
    *) argv+=("$1");;
  esac
  shift
done
set -- "${argv[@]}"

upload=
apiKey=
endpoint=https://scrn.is/api/v1/upload
out=
save=
copy=
filetype=png
dateArgs=()
grimblastArgs=()

positional=()
ignoreOpts=
while [[ $# -gt 0 ]]; do
  case "$ignoreOpts$1" in
    -u|--upload) upload=1;;
    -a|--api-key) apiKey="$2"; shift;;
    -e|--endpoint) endpoint="$2"; shift;;
    -o|--output) out="$2"; save=1; shift;;
    -U|--utc) dateArgs+=(-u);;
    -C|--copy) copy=1;;
    -f|--freeze) grimblastArgs+=(--freeze);;
    -w|--wait) grimblastArgs+=(--wait "$2"); shift;;
    -s|--scale) grimblastArgs+=(--scale "$2"); shift;;
    -c|--cursor) grimblastArgs+=(--cursor);;
    -t|--filetype) grimblastArgs+=(--filetype "$2"); filetype="$2"; shift;;
    -h|--help) usage; exit 0;;
    --) ignoreOpts=1;;
    -*) fatalUser "invalid option $1";;
    *) positional+=("$1");;
  esac
  shift
done
set -- "${positional[@]}"

target="$1"; shift
action=
case 1 in
  $((copy && !upload))) action+="copy";;&
  $((save || upload))) action+="save";;
esac
grimblastArgs+=("$action" "$target")

check \
  "extraneous positional arguments ($*)" $# ""\
  "missing target" 1 "$target" \
  "missing one of --copy --output --upload" 1 "$action" \
  "missing value for --api-key" "$upload" "$apiKey" \
  "missing value for --output" "$save" "$out" \

if [[ $((!save && upload)) -ne 0 ]]; then
  out="$(mktemp --suffix ".$filetype" "$(printf 'X%.0s' {1..8})")"
  trap "$(trap -P EXIT)"$'\n rm -f "$out"' EXIT
elif [[ "$save" -ne 0 ]]; then
  out="$(date "${dateArgs[@]}" "+${out/#\~/$HOME}")" \
    || fatal "date returned non-zero status"
fi
[[ -n "$out" ]] && grimblastArgs+=("$out")

if [[ "$upload" -ne 0 ]]; then
  case "${apiKey:0:1}" in
    @|%) apiKey=${apiKey:1};;&
    @)
      apiKeyRaw="$(<"${apiKey/#\~/$HOME}")" \
        || fatal "could not read API key from file: ${apiKey}"
      ;;
    %)
      apiKeyRaw="$(bash -c "${apiKey}")" \
        || fatal "API key command returned non-zero status: ${apiKey}"
      ;;
    *) apiKeyRaw="$apiKey";;
  esac
  apiKey="$(tr -d '[:space:]' <<<"$apiKeyRaw")"
fi

set -eo pipefail
mkdir -p "$(dirname "$out")"
grimblast "${grimblastArgs[@]}" >/dev/null

if [[ "$upload" -ne 0 ]]; then
  response="$(curl -sS --fail-with-body \
    "$endpoint" \
    -F "image=@$out" \
    -H "Authorization: Bearer $apiKey")"
  url="$(jq -r .url <<<"$response")"
  printf "%s" "$url"
  if [[ "$copy" -ne 0 ]]; then
    tr -d '[:space:]' <<<"$url" | wl-copy
  fi
fi
