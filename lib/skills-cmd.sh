#!/usr/bin/env bash
# uk skills - the Claude skills and plugins each Claude profile has (bin/uk runs this file). Each comes from
# unikit or a layer: a skill from claude/skills/<name>/ (a profile has it when its skills/<name> links
# there), a plugin from a line in claude/plugins (installed in the profile by claude plugin install).
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

sk_pname() { if [[ $1 == "$HOME/.claude" ]]; then echo default; else basename "$1"; fi; }

# skills ls: a row per skill or plugin: its type, layer and the profiles that have it (✓ every one, ◐ some)
sk_ls() {
  local n l k s p have c np S=$'\x1f'
  np=$(claude_dirs | grep -c .)
  {
    printf '%s\n' "${C_BOLD}NAME$S${C_BOLD}TYPE$S${C_BOLD}LAYER$S${C_BOLD}PROFILES$C_RESET"
    while IFS=$'\t' read -r n l k s _; do
      have="" c=0
      while IFS= read -r p; do
        sk_has "$p" "$k" "$n" "$s" && { have+="${have:+, }$(sk_pname "$p")"; (( c++ )); }
      done < <(claude_dirs)
      if (( ! c )); then have="$C_DIM– none$C_RESET"
      elif (( c == np )); then have="$C_GREEN✓$C_RESET $have"
      else have="$C_YELLOW◐$C_RESET $have"; fi
      printf '%s\n' "$n$S$k$S$C_DIM$l$C_RESET$S$have"
    done < <(sk_items)
  } | ui_table "uk skills" "$np profiles" "$(ui_hint uk skills) to change them"
}

# skills <name>: what it's for, where it comes from, each profile
sk_show() {
  local n l k s w p rows
  IFS=$'\t' read -r n l k s w < <(sk_items | awk -F'\t' -v n="$1" '$1 == n')
  [[ -n ${n:-} ]] || { printf 'uk skills: no skill or plugin named %s (uk skills ls lists them)\n' "$1" >&2; exit 2; }
  if [[ $k == plugin ]]; then rows=$(printf 'about\t%s\ntype\tplugin\nlayer\t%s\nfrom\tgithub.com/%s\n' "$w" "$l" "${s#*|}")
  else rows=$(printf 'about\t%s\ntype\tskill\nlayer\t%s\nfolder\t%s\n' "$w" "$l" "${s/#$HOME/\~}"); fi
  while IFS= read -r p; do
    if sk_has "$p" "$k" "$n" "$s"; then rows+=$'\n'"$(sk_pname "$p")"$'\t'"$C_GREEN✓$C_RESET has it"
    else rows+=$'\n'"$(sk_pname "$p")"$'\t'"$C_DIM– not set up$C_RESET"; fi
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
    ui_help "uk skills" "the Claude skills and plugins each Claude profile has" <<'EOF'
## Commands
uk skills	pick which profiles get which skills and plugins: tab ticks, alt-g by profile, ctrl-p the details pane
uk skills ls	a row per skill or plugin: its type, layer and the profiles that have it (✓ every one, ◐ some)
uk skills <name>	one of them: what it's for, where it comes from, each profile
uk skills help	this page

They come from unikit and its layers: skills from claude/skills/<name> (each profile links the
ones it has), plugins from claude/plugins (installed in each profile by claude plugin install).
EOF
    ;;
  -*) printf 'uk skills: no such option: %s (uk skills help)\n' "$1" >&2; exit 2 ;;
  *) sk_show "$1" ;;
esac
