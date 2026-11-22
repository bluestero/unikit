# What tk and fk share. The kits are siblings: the same words, the same pages, each one
# empty until layers fill it (lib/layers.sh: a layer's tools lines, its bin/<kit>-<name>
# subcommands, its parts). bin/tk and bin/fk set these, then source this file and call kit_main:
#   ROOT, SELF   the toolkit folder, the kit's own command
#   KIT          tk | fk
#   KIT_WHAT     one line on what the kit is for
#   KIT_TOOLS    (optional) tools lines of the kit's own, name|group|what|needs|kit|layer
#   kit_help_own (optional) help lines for the kit's own extra commands, with a "## " heading
#   kit_own      (optional) kit_own <word> [args]: runs one of those; returns 2 when it isn't one
# Every kit has: <kit> (picker), ls, install, uninstall, help, and <kit> <name> for a
# layer's bin/<kit>-<name>.

# shellcheck source=ui.sh
. "$ROOT/lib/ui.sh"
# shellcheck source=layers.sh
. "$ROOT/lib/layers.sh"
S=$'\x1f'
KIT_EMPTY="Nothing here yet. Add a layer: uk layers"
KIT_TITLE="$KIT · ${KIT_LABEL[$KIT]}"

TOOLS=("${KIT_TOOLS[@]}")
while IFS= read -r _t; do TOOLS+=("$_t"); done < <(layer_tools "$ROOT" "$KIT")
unset _t
field() { cut -d'|' -f"$2" <<<"$1"; }

# "✓ ready" or why not; 1 when not
kit_ready() {
  local name need
  name=$(field "$1" 1); need=$(field "$1" 4)
  if [[ $name == "$KIT "* ]]; then   # a subcommand: the layer's bin/<kit>-<name>
    layer_bin "$ROOT" "$KIT-${name#"$KIT "}" >/dev/null || { printf '%s' "${C_YELLOW}missing${C_RESET}"; return 1; }
  else
    type -P "$name" >/dev/null || { printf '%s' "${C_YELLOW}not on PATH${C_RESET}  $(ui_hint 'tk install commands')"; return 1; }
  fi
  [[ -z $need ]] || type -P "$need" >/dev/null || { printf '%s' "${C_YELLOW}needs $need${C_RESET}"; return 1; }
  printf '%s' "${C_GREEN}✓ ready${C_RESET}"
}

kit_ls() {
  [[ -t 1 ]] || ui_no_color
  (( ${#TOOLS[@]} )) || { info "$KIT_EMPTY"; return 0; }
  local t prev="" g st
  {
    printf '%s\n' "${C_BOLD}COMMAND${C_RESET}$S${C_BOLD}WHAT IT DOES${C_RESET}$S${C_BOLD}LAYER${C_RESET}$S${C_BOLD}READY${C_RESET}"
    for t in "${TOOLS[@]}"; do
      g=$(field "$t" 2)
      if [[ $g != "$prev" ]]; then [[ -n $prev ]] && printf '\n'; printf '%s\n' "$C_DIM$g$C_RESET"; prev=$g; fi
      st=$(kit_ready "$t")
      printf '%s\n' "  $C_CYAN$(field "$t" 1)$C_RESET$S$(field "$t" 3)$S$C_DIM$(field "$t" 6)$C_RESET$S$st"
    done
  } | ui_table "$KIT_TITLE" "${#TOOLS[@]} commands" "$(ui_hint '<command> help for each one')"
}

# The picker: enter runs the command. A plain command runs in the calling shell when the
# kit's shell hook asked for it (so okcli and kx can change this terminal).
kit_pick() {
  if [[ ! -t 0 || ! -t 1 ]] || ! type -P fzf >/dev/null; then kit_ls; return; fi
  (( ${#TOOLS[@]} )) || { info "$KIT_EMPTY"; return 0; }
  local t rows="COMMAND${S}AREA${S}WHAT IT DOES${S}LAYER"$'\n' sel
  for t in "${TOOLS[@]}"; do
    rows+="$(field "$t" 1)$S${C_DIM}$(field "$t" 2)${C_RESET}$S$(field "$t" 3)$S${C_DIM}$(field "$t" 6)${C_RESET}"$'\n'
  done
  sel=$(printf '%s' "$rows" | ui_fzf "$KIT_TITLE" --sortable --header-lines=1 --prompt='command> ' \
    --header='enter: run it · esc: cancel') || return 0
  sel=$(strip_ansi "$sel"); sel=${sel%%   *}   # the first cell: cells are 3 or more spaces apart
  [[ -n $sel ]] || return 0
  # shellcheck disable=SC2086   # a command and its words ("fk looks")
  set -- $sel
  if [[ $1 == "$KIT" ]]; then shift; exec "$SELF" "$@"; fi
  emit_eval "$1" || exec "$1"
}

kit_help() {
  local t
  {
    printf '## Commands\n'
    printf '%s\tpick one of the commands below and run it\n' "$KIT"
    printf '%s ls\tthe commands below: what each does, its layer, ready or what it needs\n' "$KIT"
    printf '%s install [part...]\tset up the %s parts the layers bring: a tab per group, then one question per change\t%s install ls lists them\n' "$KIT" "$KIT" "$KIT"
    printf '%s uninstall [part...]\tremove them, putting your own settings back\n' "$KIT"
    printf '%s help\tthis page\n' "$KIT"
    if declare -F kit_help_own >/dev/null; then printf '\n'; kit_help_own; fi
    printf '\n## From the layers\n'
    if (( ${#TOOLS[@]} )); then
      for t in "${TOOLS[@]}"; do printf '%s\t%s\t%s\n' "$(field "$t" 1)" "$(field "$t" 3)" "$(field "$t" 6)"; done
    else
      printf '%s\n' "$KIT_EMPTY"
    fi
  } | ui_help "$KIT" "${KIT_LABEL[$KIT]}: $KIT_WHAT"
}

kit_main() {
  local sub rc
  case "${1:-}" in
    "")             kit_pick ;;
    ls|list)        kit_ls ;;
    install)        shift; exec "$ROOT/install.sh" --kit="$KIT" "$@" ;;
    uninstall)      shift; exec "$ROOT/uninstall.sh" --kit="$KIT" "$@" ;;
    help|-h|--help) kit_help ;;
    *)
      if declare -F kit_own >/dev/null; then
        kit_own "$@"; rc=$?
        (( rc == 2 )) || exit "$rc"
      fi
      sub=$(layer_bin "$ROOT" "$KIT-$1") || ui_unknown "$KIT" "$1"
      shift; exec "$sub" "$@" ;;
  esac
}
