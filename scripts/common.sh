#!/usr/bin/env bash

# This file is intended to be sourced by scripts in sbf/scripts.

SCRIPTDIR="$(dirname -- "$(readlink -f -- "${BASH_SOURCE[0]}")")"
SBF_ROOT="$(readlink -f -- "$SCRIPTDIR/../..")"

CALABASH="${CALABASH:-$SBF_ROOT/calabash/calabash.sh}"
SCHEMA_CACHE="${SCHEMA_CACHE:-$SBF_ROOT/schema-cache}"
