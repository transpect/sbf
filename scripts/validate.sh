#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
# shellcheck source=common.sh
source "$SCRIPT_DIR/common.sh"

usage() {
  cat <<'EOF'
Usage:
  validate.sh (-s SCHEMA | -p PROFILE) [-o DIR [-r]] [-d DEBUGDIR] INPUT
  validate.sh (-s SCHEMA | -p PROFILE) -a FILE [-d DEBUGDIR] INPUT

Options:
  -s SCHEMA    Schema file path or file: URI
  -p PROFILE   Profile name; loads PROFILE.compiled.nvdl from SCHEMA_CACHE
  -o DIR       Output directory (default: /dev/null)
  -a FILE      Write archive output to FILE; selects validation-archive.xpl
  -r           Render HTML only; requires -o and cannot be combined with -a
  -d DEBUGDIR  Enable debugging and use DEBUGDIR for debug output
  -h           Show this help

Environment:
  CALABASH     Calabash launcher (default: $SBF_ROOT/calabash/calabash.sh)
  SCHEMA_CACHE Profile cache directory (default: $SBF_ROOT/schema-cache)
EOF
}

die() {
  printf 'validate.sh: %s\n' "$*" >&2
  exit 2
}

SCHEMA=""
PROFILE=""
OUTPUT_DIR="out"
OUTPUT_DIR_SET=false
ARCHIVE=""
RENDERING_ONLY=false
DEBUG=false
DEBUG_DIR=""

while getopts ':s:p:o:a:rd:h' opt; do
  case "$opt" in
    s) SCHEMA=$OPTARG ;;
    p) PROFILE=$OPTARG ;;
    o) OUTPUT_DIR=$OPTARG; OUTPUT_DIR_SET=true ;;
    a) ARCHIVE=$OPTARG ;;
    r) RENDERING_ONLY=true ;;
    d) DEBUG=yes; DEBUG_DIR=$OPTARG ;;
    h) usage; exit 0 ;;
    :) die "option -$OPTARG requires an argument" ;;
    \?) die "unknown option: -$OPTARG" ;;
  esac
done
shift "$((OPTIND - 1))"

if [[ $# -eq 0 ]]; then
  usage >&2
  exit 2
fi

[[ -n "$SCHEMA" || -n "$PROFILE" ]] ||
  die "specify exactly one of -s SCHEMA or -p PROFILE"
[[ -z "$SCHEMA" || -z "$PROFILE" ]] ||
  die "options -s and -p are mutually exclusive"
[[ $# -eq 1 ]] || {
  usage >&2
  exit 2
}
INPUT=$1

[[ -x "$CALABASH" ]] ||
  die "Calabash launcher is not executable: $CALABASH"

if [[ -n "$ARCHIVE" ]]; then
  [[ "$OUTPUT_DIR_SET" == false ]] ||
    die "options -a and -o are mutually exclusive"
  [[ "$RENDERING_ONLY" == false ]] ||
    die "option -r cannot be combined with -a"
  PIPELINE="$SBF_ROOT/sbf/validate/validation-archive.xpl"
else
  [[ "$RENDERING_ONLY" == false || "$OUTPUT_DIR_SET" == true ]] ||
    die "option -r requires an explicit -o DIR"
  PIPELINE="$SBF_ROOT/sbf/validate/validate.xpl"
fi

if [[ -n "$PROFILE" ]]; then
  SCHEMA="${SCHEMA_CACHE%/}/${PROFILE}.compiled.nvdl"
  [[ -f "$SCHEMA" ]] ||
    die "compiled profile not found: $SCHEMA"
elif [[ "$SCHEMA" != file:* ]]; then
  [[ -f "$SCHEMA" ]] || die "schema file not found: $SCHEMA"
fi

if [[ "$INPUT" != file:* ]]; then
  [[ -f "$INPUT" ]] || die "input file not found: $INPUT"
fi

if [[ -n "$ARCHIVE" ]]; then
  [[ "$ARCHIVE" != file:* ]] ||
    die "for -a, supply a filesystem output path rather than a file: URI"
  [[ -d "$(dirname -- "$ARCHIVE")" ]] ||
    die "archive output directory does not exist: $(dirname -- "$ARCHIVE")"
fi

ARGS=(
  "--input:source=$INPUT"
  "--input:schema=$SCHEMA"
  "--temporary-files"
)

OPTIONS=(
  "debug=$DEBUG"
)

if [[ -n "$ARCHIVE" ]]; then
  ARGS+=("--output:result=$ARCHIVE")
else
  # The pipeline writes its deliverables itself, using output-dir.
  ARGS+=("--output:result=/dev/null")
  OPTIONS+=("output-dir=$OUTPUT_DIR" "rendering-only=$RENDERING_ONLY")
fi

if [[ -n "$DEBUG_DIR" ]]; then
  OPTIONS+=("debug-dir=$DEBUG_DIR")
fi

# Do not change directory: relative paths retain the caller's CWD.
CFG=none "$CALABASH" \
  "${ARGS[@]}" \
  "$PIPELINE" \
  "${OPTIONS[@]}"
