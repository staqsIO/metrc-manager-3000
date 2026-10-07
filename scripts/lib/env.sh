#!/usr/bin/env bash
# Helpers to read/write KEY=VALUE lines in a dotenv file without disturbing other lines.
env_get() { # FILE KEY
  [ -f "$1" ] || return 0
  grep -E "^$2=" "$1" | tail -1 | cut -d= -f2- | sed -E 's/[[:space:]]+#.*$//; s/[[:space:]]+$//'
}

env_set() { # FILE KEY VALUE
  local file="$1" key="$2" value="$3" tmp
  tmp="$(mktemp)"
  if grep -qE "^$key=" "$file"; then
    K="$key" V="$value" awk 'BEGIN{FS=OFS="="; k=ENVIRON["K"]; v=ENVIRON["V"]} $1==k {print k "=" v; next} {print}' "$file" > "$tmp"
  else
    cat "$file" > "$tmp"; printf '%s=%s\n' "$key" "$value" >> "$tmp"
  fi
  cat "$tmp" > "$file"; rm -f "$tmp"
}

env_set_if_empty() { # FILE KEY VALUE
  [ -n "$(env_get "$1" "$2")" ] || env_set "$1" "$2" "$3"
}
