#!/usr/bin/env bash

argv0="imsh-cast"

usage() {
cat <<EOF
$argv0 - Capture and optionally upload a screencast to an imsh server

Usage: $argv0 [options...]

Options:
  -u, --upload
    Uploads the screencast to imsh.

  -a, --api-key=key|@file|%cmd
    API key for uploading to imsh.
    Prefix with "@" to read from a file.
    Prefix with "%" to run a command.

  -e, --endpoint=url
    The imsh endpoint to upload to.
    Defaults to https://scrn.is/api/v1/upload

  -o, --output=path-pattern
    Path to write captured screencast to. Gets passed through date and
    supports the same format strings.

  -U, --utc
    Call date with -u to use UTC for added privacy when sharing.

  -C, --copy
    Copy the absolute filesystem path of the screencast to the
    clipboard. If uploading, instead copy the returned URL.

  --pid-file=path
    Specify the path to read/write PID from. If a file is found at this
    location any other arguments will be ignored, and the PID contained
    within will be sent a SIGINT.
    Defaults to: \$XDG_RUNTIME_DIR/$argv0-0.pid

  -t, --filetype=ext
    Specifies the file extension for the temporary file used when no
    output is specified. This has no effect when an output is specified.
    Default: mp4

  -A, --audio
    Records audio in addition to video. To specify a device to record
    from use --audio-device instead.

  --audio-device=name
    Specify the device to record audio from. Implies --audio.

  -c, --codec=codec
    Specifies the codec of the video. These can be found by using:
    ffmpeg -encoders

  -r, --framerate=number
    Specifies a constant framerate.

  -d, --device=name
    Selects the device to use when encoding the video.

  --no-dmabuf
    Forces CPU copy while for recording.

  -D, --no-damage
    Continuously records even when there are no new frames.

  -m, --muxer=name
    Specifies the output format to a specific muxer instead of detecting
    it from the filename.

  -x, --pixel-format=name
    Specifies the output pixel format. These can be found by running:
    ffmpeg -pix_fmts

  -O, --display-output
    Specifies the display output to record.

  -p, --codec-param=option=value
    Change video codec parameters.

  -F, --filter=option=value
    Specifies the ffmpeg filter string to use.

  -b, --bframes=number
    Specifies the max number of b-frames to be used. If b-frames are not
    supported by your hardware, set this to 0.

  -B, --buffrate=number
    Specifies the buffer's expected framerate.

  --audio-backend=name
    Specifies the audio bakcned to use, e.g. pipewire.

  --audio-codec=codec
    Specifies the audio codec. These can be found by running:
    ffmpeg -encoders

  -X, --sample-format=fmt
    Specifies the audio sample format. These can be found by running:
    ffmpeg -sample_fmts

  -R, --sample-rate=number
    Specifies the audio sample rate in Hz.
    Default: 48000

  -P, --audio-codec-param=option=value
    Change audio codec parameters.

  -y, --overwrite
    Force overwriting the output file without prompting.

  -h, --help
    Display this message.
EOF
}

info() {
  printf "Info: %s\n" "$1" >&2
}

warn() {
  printf "Warning: %s\n" "$1" >&2
}

fatal() {
  printf "Error: %s\n" "$1" >&2
  exit 1
}

fatalUser() {
cat >&2 <<EOF
Error: $1

See $argv0 --help for more information.
EOF
exit 2
}

checkInput() {
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
  --audio-device
  -c --codec
  -r --framerate
  -d --device
  -t --filetype
  -m --muxer
  -x --pixel-format
  -p --codec-param
  -F --filter
  -b --bframes
  -B --buffrate
  --audio-backend
  --audio-codec
  -X --sample-format
  -R --sample-rate
  -P --audio-codec-param
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
pidFile="$XDG_RUNTIME_DIR/$argv0-0.pid"
filetype=mp4
dateArgs=()
wfRecorderArgs=()

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
    --pid-file) pidFile="$2"; shift;;
    -t|--filetype) filetype="$2"; shift;;
    -A|--audio) wfRecorderArgs+=(--audio);;
    --audio-device) wfRecorderArgs+=("--audio=$2"); shift;;
    -c|--codec) wfRecorderArgs+=(--codec "$2"); shift;;
    -r|--framerate) wfRecorderArgs+=(--framerate "$2"); shift;;
    -d|--device) wfRecorderArgs+=(--device "$2"); shift;;
    --no-dmabuf) wfRecorderArgs+=(--no-dmabuf);;
    -D|--no-damage) wfRecorderArgs+=(--no-damage);;
    -m|--muxer) wfRecorderArgs+=(--muxer "$2"); shift;;
    -x|--pixel-format) wfRecorderArgs+=(--pixel-format "$2"); shift;;
    -O|--display-output) wfRecorderArgs+=(--output "$2"); shift;;
    -p|--codec-param) wfRecorderArgs+=(--codec-param "$2"); shift;;
    -F|--filter) wfRecorderArgs+=(--filter "$2"); shift;;
    -b|--bframes) wfRecorderArgs+=(--bframes "$2"); shift;;
    -B|--buffrate) wfRecorderArgs+=(--buffrate "$2"); shift;;
    --audio-backend) wfRecorderArgs+=(--audio-backend "$2"); shift;;
    --audio-codec) wfRecorderArgs+=(--audio-codec "$2"); shift;;
    -X|--sample-format) wfRecorderArgs+=(--sample-format "$2"); shift;;
    -R|--sample-rate) wfRecorderArgs+=(--sample-rate "$2"); shift;;
    -P|--audio-codec-param) wfRecorderArgs+=(--audio-codec-param "$2"); shift;;
    -y|--overwrite) wfRecorderArgs+=(--overwrite);;
    -h|--help) usage; exit 0;;
    --) ignoreOpts=1;;
    -*) fatalUser "invalid option: $1";;
    *) positional+=("$1");;
  esac
  shift
done
set -- "${positional[@]}"

if [[ -e "$pidFile" ]]; then
  set -e
  info "found PID file: $pidFile"
  pid="$(tr -d '[:space:]' <"$pidFile")"
  if [[ "$pid" -gt 0 ]]; then
    info "sending SIGINT to PID $pid"
    kill -INT "$pid"
  else
    warn "PID file empty or malformed: $pid"
  fi
  info "deleting PID file: $pidFile"
  rm -f "$pidFile"
  exit 0
fi

checkInput \
  "extraneous positional arguments ($*)" $# ""\
  "missing one of --output --upload" 1 "$save$out$upload" \
  "missing value for --api-key" "$upload" "$apiKey" \
  "missing value for --output" "$save" "$out" \

if [[ $((!save && upload)) -ne 0 ]]; then
  out="$(mktemp --suffix ".$filetype" "$(printf 'X%.0s' {1..8})" --tmpdir)"
  wfRecorderArgs+=(--overwrite)
  trap "$(trap -P EXIT)"$'\nrm -f "$out"' EXIT
else
  out="$(date "${dateArgs[@]}" "+${out/#\~/$HOME}")" \
    || fatal "date returned non-zero status"
fi
wfRecorderArgs+=(-f "$out")

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

area="$(slurp)"
wfRecorderArgs+=(--geometry "$area")

mkdir -p "$(dirname "$out")"
wf-recorder "${wfRecorderArgs[@]}" >/dev/null &
pid=$!
trap "$(trap -P EXIT)"$'\nfor pid in $(jobs -p); do kill $pid; done' EXIT
printf "%d" $pid >"$pidFile" \
  || fatal "wl-recorder unable to write PID: $pidFile"
wait $pid \
  || fatal "wl-recorder returned non-zero status"

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
elif [[ "$copy" -ne 0 ]]; then
  printf "%s" "$out" | wl-copy
fi

