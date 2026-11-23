#!/usr/bin/env bash
# uk skills - the Claude skills each Claude profile has (bin/uk runs this file). Every skill comes from unikit or a
# layer (claude/skills/<name>/); a profile has it when its skills/<name> links there.
# The same picker as tk install claude-skill (lib/skills.sh), on its own.
set -uo pipefail
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
repo="$(cd "$(dirname "$SELF")/.." && pwd)"
mode=ask details=0 ok_pad=""
# shellcheck source=../lib/setup.sh
. "$repo/lib/setup.sh"
# shellcheck source=../lib/components.sh
. "$repo/lib/components.sh"
[[ -t 1 ]] || ui_no_color

# every skill: "name TAB layer TAB folder" (a name twice: the first one, as the picker)
sk_all() {
  local d n l seen=" "
  for d in "$repo"/claude/skills/*/ "$repo"/layers/*/claude/skills/*/; do
    [[ -d $d ]] || continue
    d=${d%/}; n=${d##*/}
    [[ $seen == *" $n "* ]] && continue; seen+="$n "
    l=unikit; [[ $d == "$repo"/layers/* ]] && { l=${d#"$repo"/layers/}; l=${l%%/*}; }
    printf '%s\t%s\t%s\n' "$n" "$l" "$d"
  done
}
sk_pname() { if [[ $1 == "$HOME/.claude" ]]; then echo default; else basename "$1"; fi; }
sk_about() { sed -n 's/^description: *//p' "$1/SKILL.md" 2>/dev/null | head -1; }

# skills ls: a row per skill: its layer and the profiles that have it (✓ every one, ◐ some)
sk_ls() {
  local n l d p have c np S=$'\x1f'
  np=$(claude_dirs | grep -c .)
  {
    printf '%s\n' "${C_BOLD}SKILL$S${C_BOLD}LAYER$S${C_BOLD}PROFILES$C_RESET"
    while IFS=$'\t' read -r n l d; do
      have="" c=0
      while IFS= read -r p; do
        linked "$p/skills/$n" "$d" && { have+="${have:+, }$(sk_pname "$p")"; (( c++ )); }
      done < <(claude_dirs)
      if (( ! c )); then have="$C_DIM– none$C_RESET"
      elif (( c == np )); then have="$C_GREEN✓$C_RESET $have"
      else have="$C_YELLOW◐$C_RESET $have"; fi
      printf '%s\n' "$n$S$C_DIM$l$C_RESET$S$have"
    done < <(sk_all)
  } | ui_table "uk skills" "$np profiles" "$(ui_hint uk skills) to change them"
}

# skills <name>: what it's for, where it comes from, each profile
sk_show() {
  local n l d p rows
  IFS=$'\t' read -r n l d < <(sk_all | awk -F'\t' -v n="$1" '$1 == n')
  [[ -n ${n:-} ]] || { printf 'uk skills: no skill named %s (uk skills ls lists them)\n' "$1" >&2; exit 2; }
  rows=$(printf 'about\t%s\nlayer\t%s\nfolder\t%s\n' "$(sk_about "$d")" "$l" "${d/#$HOME/\~}")
  while IFS= read -r p; do
    if linked "$p/skills/$n" "$d"; then rows+=$'\n'"$(sk_pname "$p")"$'\t'"$C_GREEN✓$C_RESET has it"
    else rows+=$'\n'"$(sk_pname "$p")"$'\t'"$C_DIM– not linked$C_RESET"; fi
  done < <(claude_dirs)
  printf '%s\n' "$rows" | ui_fields "uk skills · $n"
}

case "${1:-}" in
  "")
    if [[ -t 0 && -t 1 ]] && type -P fzf >/dev/null && ui_fzf_at_least 0.63; then
      # shellcheck source=../lib/skills.sh
      . "$repo/lib/skills.sh"; sk_pick
    else sk_ls; fi ;;
  ls|list) sk_ls ;;
  help|-h|--help)
    ui_help "uk skills" "the Claude skills each Claude profile has" <<'EOF'
## Commands
uk skills	pick which profiles get which skills: tab ticks, alt-g by profile, ctrl-p the details pane
uk skills ls	a row per skill: its layer and the profiles that have it (✓ every one, ◐ some)
uk skills <name>	one skill: what it's for, where it comes from, each profile
uk skills help	this page

Skills come from unikit and its layers (claude/skills/<name>); each profile links the ones it has.
EOF
    ;;
  -*) printf 'uk skills: no such option: %s (uk skills help)\n' "$1" >&2; exit 2 ;;
  *) sk_show "$1" ;;
esac
