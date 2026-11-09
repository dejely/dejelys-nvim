#!/usr/bin/env bash
set -euo pipefail
[[ $# = 1 && -d $1 ]] || { echo 'Usage: bash scripts/restore.sh BACKUP_DIRECTORY' >&2; exit 2; }
backup=$(cd "$1" && pwd -P)
for index in 1 2 3 4; do
  [[ -f $backup/$index.path ]] || { echo 'Not an installer backup (missing path records)' >&2; exit 1; }
  IFS= read -r directory < "$backup/$index.path"
  [[ $directory = /* && $directory = */nvim ]] || { echo 'Unexpected target in backup' >&2; exit 1; }
done
[[ ! -f $backup/RESTORED ]] || { echo 'This backup was already restored.' >&2; exit 1; }
displaced=$(mktemp -d "${backup}.displaced.XXXXXXXX")
seen=()
for index in 1 2 3 4; do
  IFS= read -r directory < "$backup/$index.path"
  duplicate=0
  for previous in "${seen[@]+"${seen[@]}"}"; do
    if [[ $previous = "$directory" ]]; then duplicate=1; fi
  done
  [[ $duplicate = 0 ]] || continue
  seen+=("$directory")
  if [[ -e $directory || -L $directory ]]; then mv "$directory" "$displaced/$index"; fi
  if [[ -e $backup/$index || -L $backup/$index ]]; then
    mkdir -p "$(dirname "$directory")"
    mv "$backup/$index" "$directory"
  fi
done
printf '%s\n' "$displaced" > "$backup/RESTORED"
echo "Previous setup restored. Displaced files saved at: $displaced"
