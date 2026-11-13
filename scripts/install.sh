#!/usr/bin/env bash
# One-line installer: curl -fsSL https://raw.githubusercontent.com/staqsIO/metrc-manager-3000/main/scripts/install.sh | bash
set -euo pipefail
ORG="${GITHUB_ORG:-staqsIO}"
# Installs made before the rename to METRC Manager 3000 keep their metrc-formul8-os folders.
if [ -n "${METRC_OS_DIR:-}" ]; then DIR="$METRC_OS_DIR"
elif [ -d "$PWD/metrc-formul8-os/metrc-formul8-os" ]; then DIR="$PWD/metrc-formul8-os"
else DIR="$PWD/metrc-manager-3000"; fi
SSH=0; ARGS=()
for a in "$@"; do if [ "$a" = "--ssh" ]; then SSH=1; else ARGS+=("$a"); fi; done
[ "$SSH" = 1 ] || ARGS+=("--https")

command -v git >/dev/null || { echo "git is required" >&2; exit 1; }
mkdir -p "$DIR"
REPO_DIR="$DIR/metrc-manager-3000"
[ ! -d "$DIR/metrc-formul8-os" ] || REPO_DIR="$DIR/metrc-formul8-os"
if [ ! -d "$REPO_DIR" ]; then
  if [ "$SSH" = 1 ]; then url="git@github.com:$ORG/metrc-manager-3000.git"; else url="https://github.com/$ORG/metrc-manager-3000.git"; fi
  git clone --depth 1 "$url" "$REPO_DIR"
fi
cd "$REPO_DIR"
if [ ! -t 0 ] && { : </dev/tty; } 2>/dev/null; then exec bash scripts/setup.sh ${ARGS[@]+"${ARGS[@]}"} </dev/tty; fi
exec bash scripts/setup.sh ${ARGS[@]+"${ARGS[@]}"}
