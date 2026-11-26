# What tk and fk share. The kits are siblings: the same words, the same pages, each one
# empty until layers fill it (lib/layers.sh: a layer's tools lines, its <kit>/<name>
# subcommands, its parts). bin/tk and bin/fk set these, then source this file and call kit_main:
#   ROOT, SELF   the toolkit folder, the kit's own command
#   KIT          tk | fk
#   KIT_WHAT     one line on what the kit is for
#   KIT_TOOLS    (optional) tools lines of the kit's own, name|group|what|needs|kit|layer
#   kit_help_own (optional) help lines for the kit's own extra commands, with a "## " heading
#   kit_own      (optional) kit_own <word> [args]: runs one of those; returns 2 when it isn't one
# Every kit has: <kit> (picker), ls, install, uninstall, configs, doctor, me, help, and <kit> <name> for a
# layer's <kit>/<name>.

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
field() {   # line n: its nth |-field (as cut -d'|' -fn, without starting cut)
  [[ $1 == *'|'* ]] || { printf '%s' "$1"; return 0; }   # no | at all: the whole line, as cut
  local IFS='|' f; read -ra f <<<"$1"; printf '%s' "${f[$2 - 1]:-}"
}

# "✓ ready" or why not; 1 when not
kit_ready() {
  local name need
  name=$(field "$1" 1); need=$(field "$1" 4)
  if [[ $name == "$KIT "* ]]; then   # a subcommand: the layer's <kit>/<name>
    layer_sub "$ROOT" "$KIT" "${name#"$KIT "}" >/dev/null || { printf '%s' "${C_YELLOW}missing${C_RESET}"; return 1; }
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
# kit's shell hook asked for it (so a command that changes this terminal, like a profile or
# context switch, still can).
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
  # shellcheck disable=SC2086   # a command and its words ("fk dash2dock")
  set -- $sel
  if [[ $1 == "$KIT" ]]; then shift; exec "$SELF" "$@"; fi
  emit_eval "$1" || exec "$1"
}

# ---------------------------------------------------------------- doctor ---
# Every check of the kit in one box: one line per name when all is well, the problems (with
# their fix) when not. The checks: each command ready, each part set up, and the parts' own
# (a part's doctor_<id> prints "✓ what" / "! what — fix" lines; run when the part is set up).
declare -A OKS=() PROBLEMS=()
ORDER=() FIXES=()   # FIXES: parts whose fix is setting them up again, offered after the box
check() {  # check <name> <ok|bad> <text> [fix]
  [[ " ${ORDER[*]} " == *" $1 "* ]] || ORDER+=("$1")
  if [[ "$2" == ok ]]; then OKS[$1]=$(( ${OKS[$1]:-0} + 1 ))
  else PROBLEMS[$1]+="$3${4:+  $(ui_hint "$4")}"$'\n'; fi
}
# the parts' side, from the installer's components: "name TAB ok|bad TAB text TAB fix" lines
kit_part_checks() {
  ( repo=$ROOT mode=dry details=0
    # shellcheck source=setup.sh
    . "$ROOT/lib/setup.sh" >/dev/null 2>&1
    # shellcheck source=components.sh
    . "$ROOT/lib/components.sh" >/dev/null 2>&1
    local id d n=0 total=0 left="" line text ids
    ids=$(kit_parts "$KIT"); states_all $ids   # side by side
    for id in $ids; do
      STATE=${ST[$id]}
      [[ $STATE == n/a || $STATE == unsupported || $STATE == needs ]] && continue
      total=$((total + 1))
      [[ $STATE == installed ]] || { left+="$id "; continue; }
      n=$((n + 1))
      d=$(fn doctor "$id"); declare -F "$d" >/dev/null || continue
      while IFS= read -r line; do
        case $line in
          "✓ "*) printf '%s\tok\t%s\t\n' "$id" "${line#✓ }" ;;
          "! "*) text=${line#! }
                 if [[ $text == *" — "* ]]; then printf '%s\tbad\t%s\t%s\n' "$id" "${text%% — *}" "${text#* — }"
                 else printf '%s\tbad\t%s\t\n' "$id" "$text"; fi ;;
        esac
      done < <("$d" 2>&1 | sed 's/\x1b\[[0-9;]*m//g')
    done
    if (( total == 0 )); then :
    elif [[ -z $left ]]; then printf '%s\tok\tparts\t\n' "$KIT"
    else printf '%s\tbad\t%s of %s parts set up\t%s install %s\n' "$KIT" "$n" "$total" "$KIT" "${left% }"; fi )
}

kit_doctor() {
  [[ -t 1 ]] || ui_no_color
  local t st name ok text fix n p first rows="" bad=0
  while IFS=$'\t' read -r name ok text fix; do
    [[ -n $name ]] || continue
    check "$name" "$ok" "$text" "$fix"
    [[ $ok == bad && $name != "$KIT" && $fix == "$KIT install "* ]] && FIXES+=(${fix#"$KIT install "})
  done < <(kit_part_checks)
  for t in "${TOOLS[@]}"; do
    name=$(field "$t" 1)
    if st=$(kit_ready "$t"); then check "$name" ok ready; else check "$name" bad "$(strip_ansi "$st")"; fi
  done
  (( ${#ORDER[@]} )) || { info "$KIT_EMPTY"; return 0; }

  for name in "${ORDER[@]}"; do
    if [[ -z "${PROBLEMS[$name]:-}" ]]; then
      n=${OKS[$name]}
      rows+="$C_CYAN$name$C_RESET$S${C_GREEN}✓${C_RESET} $( (( n > 1 )) && echo "all $n checks pass" || echo ok)"$'\n'
      continue
    fi
    first="$C_CYAN$name$C_RESET"
    while IFS= read -r p; do
      [[ -n "$p" ]] || continue
      rows+="$first$S${C_YELLOW}!${C_RESET} $p"$'\n'; first=""; bad=$((bad + 1))
    done <<<"${PROBLEMS[$name]}"
    n=${OKS[$name]:-0}
    (( n == 1 )) && rows+="$S${C_DIM}1 other check passes${C_RESET}"$'\n'
    (( n > 1 )) && rows+="$S${C_DIM}$n other checks pass${C_RESET}"$'\n'
  done

  local foot; (( bad )) && foot="${C_YELLOW}$bad to fix${C_RESET}" || foot="${C_GREEN}all good${C_RESET}"
  printf '%s' "$rows" | { if [[ -t 1 ]]; then print_table 3 | ui_box "$KIT doctor" "" 0 "$foot"; else print_table 3; fi; }
  if (( bad )) && [[ -t 1 && ${#FIXES[@]} -gt 0 ]]; then
    confirm "Fix it now? ($KIT install ${FIXES[*]})" y && "$ROOT/install.sh" --kit="$KIT" "${FIXES[@]}"
  fi
  (( bad == 0 ))
}

# -------------------------------------------------------------------- me ---
# A short page about the kit: a line per thing. A list too long for the window shows what
# fits, then how many more and where to see them all.
# me_fit <width> <hint> item...: as many items as fit in width, then "+N → hint"
me_fit() {
  local w=$1 hint=$2 out="" add more n=0 plain; shift 2
  local -a items=("$@")
  for add in "${items[@]}"; do
    more=""; (( n + 1 < ${#items[@]} )) && more="  +$(( ${#items[@]} - n - 1 )) → $hint"
    plain=$(strip_ansi "${out:+$out · }$add$more")
    (( ${#plain} <= w )) || break
    out+="${out:+ · }$add"; n=$((n + 1))
  done
  (( n == ${#items[@]} )) || out+="${out:+  }$C_DIM+$(( ${#items[@]} - n )) $(ui_hint "$hint")"
  printf '%s' "$out"
}
# the kit's parts: "part TAB id TAB set-up|left" and "layer TAB name" for the layers they come from
kit_me_parts() {
  ( repo=$ROOT mode=dry details=0
    # shellcheck source=setup.sh
    . "$ROOT/lib/setup.sh" >/dev/null 2>&1
    # shellcheck source=components.sh
    . "$ROOT/lib/components.sh" >/dev/null 2>&1
    local id ids; ids=$(kit_parts "$KIT"); states_all $ids   # side by side
    for id in $ids; do
      [[ -v LAYER_OF[$id] ]] && printf 'layer\t%s\n' "${LAYER_OF[$id]}"
      case ${ST[$id]} in
        n/a|unsupported|needs) ;;
        installed) printf 'part\t%s\tset-up\n' "$id" ;;
        *)         printf 'part\t%s\tleft\n' "$id" ;;
      esac
    done )
}
kit_me() {
  [[ -t 1 ]] || ui_no_color
  local w kind a b t r d n=0 total=0 rows="" need
  local -a left=() lays=() have=() miss=() needs=(fzf git)
  w=$(( $(ui_cols) - 17 ))   # the box (6) and the names' column (8 + 3)
  (( w < 20 )) && w=20
  local -A seen=()
  while IFS=$'\t' read -r kind a b; do
    case $kind in
      layer) seen[$a]=1 ;;
      part)  total=$((total + 1)); if [[ $b == set-up ]]; then n=$((n + 1)); else left+=("$a"); fi ;;
    esac
  done < <(kit_me_parts)
  for t in "${TOOLS[@]}"; do
    seen[$(field "$t" 6)]=1
    need=$(field "$t" 4); [[ -n $need && " ${needs[*]} " != *" $need "* ]] && needs+=("$need")
  done

  r=$(rev_of "$ROOT")
  rows+="version"$'\t'"$(tr -d '[:space:]' <"$ROOT/VERSION" 2>/dev/null || printf unknown)${r:+ $C_DIM($r)$C_RESET}  $(ui_hint 'uk update')"$'\n'
  while IFS= read -r d; do
    [[ -n ${seen[${d##*/}]:-} ]] && lays+=("${d##*/} $C_DIM$(layer_ver "$d")$C_RESET")
  done < <(layer_dirs "$ROOT")
  if (( ${#lays[@]} )); then rows+="layers"$'\t'"$(me_fit "$w" 'uk version' "${lays[@]}")"$'\n'
  else rows+="layers"$'\t'"none yet  $(ui_hint 'uk layers')"$'\n'; fi
  if (( total == 0 )); then rows+="parts"$'\t'"none"$'\n'
  elif (( ${#left[@]} == 0 )); then rows+="parts"$'\t'"${C_GREEN}all $total set up${C_RESET}"$'\n'
  else
    a="${C_YELLOW}$n of $total set up${C_RESET} · missing: "
    rows+="parts"$'\t'"$a$(me_fit $(( w - ${#n} - ${#total} - 23 )) "$KIT install ls" "${left[@]}")"$'\n'
  fi
  read -r t a b < <(bash "$ROOT/lib/configs.sh" "$KIT" __count 2>/dev/null)
  if (( ${t:-0} == 0 )); then rows+="configs"$'\t'"none here"$'\n'
  else rows+="configs"$'\t'"$a of $t on the toolkit's preset$( (( b )) && printf ', %s with your patch' "$b")  $(ui_hint "$KIT configs")"$'\n'; fi
  rows+="lives in"$'\t'"${ROOT/#$HOME/\~}"$'\n'
  rows+="patches"$'\t'"~/.config/unikit/patches"$'\n'

  for t in "${needs[@]}"; do
    if ! type -P "$t" >/dev/null; then miss+=("${C_YELLOW}✗ $t${C_RESET}")
    elif [[ $t == fzf ]] && ! ui_fzf_at_least 0.63; then miss+=("${C_YELLOW}✗ fzf $(fzf --version | awk '{print $1}') (0.63+)${C_RESET}")
    elif [[ $t == fzf ]]; then have+=("${C_GREEN}✓${C_RESET} fzf $(fzf --version | awk '{print $1}')")
    else have+=("${C_GREEN}✓${C_RESET} $t"); fi
  done
  rows+="needs"$'\t'"$(me_fit "$w" "$KIT ls" "${miss[@]}" "${have[@]}")"
  printf '%s\n' "$rows" | ui_fields "$KIT_TITLE"
}

kit_help() {
  local t
  {
    printf '## Commands\n'
    printf '%s\tpick a command below and run it\n' "$KIT"
    printf '%s ls\tthe commands below: their layer, ready or not\n' "$KIT"
    printf '%s install [part...]\tset up the parts the layers bring\n' "$KIT"
    printf '%s uninstall [part...]\tremove them, your own settings back\n' "$KIT"
    printf '%s configs\teach app: the toolkit preset, its default or yours\n' "$KIT"
    printf '%s doctor\tcheck every command and part\n' "$KIT"
    printf '%s me\tabout this kit: version, layers, parts, needs\n' "$KIT"
    printf '%s help\tthis page\n' "$KIT"
    if declare -F kit_help_own >/dev/null; then printf '\n'; kit_help_own; fi
    printf '\n## From the layers\n'
    if (( ${#TOOLS[@]} )); then
      for t in "${TOOLS[@]}"; do printf '%s\t%s\n' "$(field "$t" 1)" "$(field "$t" 3)"; done
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
    configs)        shift; exec bash "$ROOT/lib/configs.sh" "$KIT" "$@" ;;
    doctor)         kit_doctor ;;
    me)             kit_me ;;
    help|-h|--help) kit_help ;;
    *)
      if declare -F kit_own >/dev/null; then
        kit_own "$@"; rc=$?
        (( rc == 2 )) || exit "$rc"
      fi
      sub=$(layer_sub "$ROOT" "$KIT" "$1") || ui_unknown "$KIT" "$1"
      shift; exec "$sub" "$@" ;;
  esac
}
