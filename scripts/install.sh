#!/usr/bin/env bash
# One-line installer: curl -fsSL https://raw.githubusercontent.com/staqsIO/metrc-formul8-os/main/scripts/install.sh | bash
set -euo pipefail
ORG="${GITHUB_ORG:-staqsIO}"
DIR="${METRC_OS_DIR:-$PWD/metrc-formul8-os}"
SSH=0; ARGS=()
for a in "$@"; do if [ "$a" = "--ssh" ]; then SSH=1; else ARGS+=("$a"); fi; done
[ "$SSH" = 1 ] || ARGS+=("--https")

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
mkdir -p "$DIR"
if [ ! -d "$DIR/metrc-formul8-os" ]; then
  if [ "$SSH" = 1 ]; then url="git@github.com:$ORG/metrc-formul8-os.git"; else url="https://github.com/$ORG/metrc-formul8-os.git"; fi
  git clone --depth 1 "$url" "$DIR/metrc-formul8-os"
fi
cd "$DIR/metrc-formul8-os"
if [ ! -t 0 ] && { : </dev/tty; } 2>/dev/null; then exec bash scripts/setup.sh ${ARGS[@]+"${ARGS[@]}"} </dev/tty; fi
exec bash scripts/setup.sh ${ARGS[@]+"${ARGS[@]}"}
