# The Claude skills and plugins picker (uk skills, and tk install claude-skill in a terminal; fzf
# 0.63+). Each comes from unikit or a layer: a skill is a folder (claude/skills/<name>/) that each
# Claude profile links; a plugin is a line in claude/plugins, installed in each profile with
# claude plugin install. One list, open throughout:
#   by skill (the start)   a row per skill or plugin: its layer, the profiles that have it (names while
#                          they fit, else 3/7). Ticked: in every profile; ◐ (some) starts unticked.
#                          enter: then which profiles (ticked: those that have the picked skills)
#   by profile (alt-g)     a row per profile and skill: ticks pick exact pairs; enter applies them
# Unticking something that is set up removes it, asked first in the list's header (default No).
# The pane shows the skill under the cursor in each profile (✓ / –): ctrl-p opens it on the
# right, again below, again closes it (it starts closed).
# install.sh sources it for sk_pick; fzf's callbacks run it as a script (bash lib/skills.sh
# <what> <state dir> ...), which loads only lib/ui.sh and lib/inplace.sh.
#
# The state dir ($T, also lib/inplace.sh's $IP):
#   prof     the profile folders, one per line         skills  lib/components.sh's sk_items
#   have     "name TAB profile": linked now             full    the skills linked in every profile
#   on.skill / on.pair / on.prof   what's ticked in each view (on.pair: "name TAB profile")
#   view     skill | pair | prof                        rows    the open view, laid out
#   add, rm  the plan ("name TAB profile")              go      made when enter applies it
#   pane     where the pane is: right | down (none: closed)

# sk_pick: the picker, then the plan carried out. Needs the installer's repo, claude_dirs, sk_items,
# sk_has, cp_add, cp_rm, link_file, unlink_file. 1 = nothing applied (esc).
sk_pick() {
  local T n k src p l cb rc=0
  T=$(mktemp -d) || return 1
  claude_dirs >"$T/prof"
  : >"$T/skills"; : >"$T/have"; : >"$T/on.prof"; echo skill >"$T/view"
  sk_items >"$T/skills"
  while IFS=$'\t' read -r n l k src _; do
    while IFS= read -r p; do sk_has "$p" "$k" "$n" "$src" && printf '%s\t%s\n' "$n" "$p" >>"$T/have"; done <"$T/prof"
  done <"$T/skills"
  [[ -s $T/skills ]] || { ok "no skills: unikit and its layers bring none"; rm -rf "$T"; return 0; }
  n=$(grep -c '' "$T/prof")
  cut -f1 "$T/have" | sort | uniq -c | awk -v n="$n" '$1 == n { print $2 }' >"$T/full"
  cp "$T/full" "$T/on.skill"; cp "$T/have" "$T/on.pair"
  cb="bash '$repo/lib/skills.sh'"
  bash "$repo/lib/skills.sh" layout "$T"
  ui_fzf 'Claude skills and plugins' --no-input --delimiter=$'\t' --with-nth=1 <"$T/rows" \
      --footer=' ' --with-shell='bash -c' \
      --preview="$cb preview '$T' {2}" --preview-window='right,40%,hidden,wrap-word' \
      --bind="ctrl-p:transform:$cb pane '$T'" \
      --bind="start:unbind(y,n)+transform:$cb header '$T'" \
      --bind="tab:transform:$cb tick '$T' {2} {n}" \
      --bind="alt-g:transform:$cb group '$T'" \
      --bind="resize:transform:$cb relayout '$T'" \
      --bind="enter:transform:$cb key '$T' enter" \
      --bind="y:transform:$cb key '$T' y" --bind="n:transform:$cb key '$T' n" \
      --bind="esc:transform:$cb key '$T' esc" >/dev/null || rc=$?
  if [[ ! -e $T/go ]]; then rm -rf "$T"; skip "nothing changed"; return 0; fi
  [[ -s $T/add || -s $T/rm ]] || ok "nothing to change"
  if cut -f1 "$T/add" "$T/rm" | grep -qxFf <(awk -F'\t' '$3 == "plugin" { print $1 }' "$T/skills") && ! type -P claude >/dev/null; then
    warn "the claude command isn't on PATH: plugins left as they are"
  fi
  while IFS=$'\t' read -r n p; do
    IFS=$'\t' read -r k src < <(awk -F'\t' -v n="$n" '$1 == n { print $3 "\t" $4 }' "$T/skills"); l=$p/skills/$n
    if [[ $k == plugin ]]; then
      type -P claude >/dev/null && cp_add "$p" "${src%%|*}" "${src#*|}" && ok "$n in ${p/#$HOME/\~}"
      continue
    fi
    [[ -e $l && ! -L $l ]] && { warn "${l/#$HOME/\~} exists and isn't a link; left alone"; continue; }
    link_file "$l" "$src" && ok "$n in ${p/#$HOME/\~}"
  done <"$T/add"
  while IFS=$'\t' read -r n p; do
    IFS=$'\t' read -r k src < <(awk -F'\t' -v n="$n" '$1 == n { print $3 "\t" $4 }' "$T/skills")
    if [[ $k == plugin ]]; then
      type -P claude >/dev/null && cp_rm "$p" "${src%%|*}" && ok "$n removed from ${p/#$HOME/\~}"
      continue
    fi
    say "  $n from ${p/#$HOME/\~}:"; unlink_file "$p/skills/$n" "$src"
  done <"$T/rm"
  rm -rf "$T"
  return 0
}

# ------------------------------------------------------------ callbacks ---
s_view() { cat "$T/view"; }
s_np() { grep -c '' "$T/prof"; }
s_on() { grep -qxF "$2" "$T/on.$1"; }
s_pname() { if [[ $1 == "$HOME/.claude" ]]; then echo default; else basename "$1"; fi; }
s_have() { grep -qxF "$1"$'\t'"$2" "$T/have"; }

# the profiles cell: ✓ / ◐ / –, then the names that have it while they fit, else 3/7
s_cell() {
  local n=$1 c names="" p np; np=$(s_np)
  c=$(awk -F'\t' -v n="$n" '$1 == n' "$T/have" | wc -l)
  (( c )) || { printf '%s' "$C_DIM– none$C_RESET"; return; }
  while IFS= read -r p; do s_have "$n" "$p" && names+="${names:+, }$(s_pname "$p")"; done <"$T/prof"
  (( ${#names} > 24 )) && names="$c/$np"   # more than a short cell holds: a count
  if (( c == np )); then printf '%s' "$C_GREEN✓$C_RESET $names"; else printf '%s' "$C_YELLOW◐$C_RESET $names"; fi
}
s_mark() { if s_on "$1" "$2"; then printf '%s' "$C_GREEN[✓]$C_RESET"; else printf '[ ]'; fi; }

# the open view's rows (title row first), the id after a TAB
s_rows() {
  local n l k p S=$'\x1f'
  case $(s_view) in
    skill)
      printf '%s\t\n' "${S}NAME${S}TYPE${S}LAYER${S}PROFILES"
      while IFS=$'\t' read -r n l k _; do
        printf '%s\t%s\n' "$(s_mark skill "$n")$S$n$S$k$S$C_DIM$l$C_RESET$S$(s_cell "$n")" "$n"
      done <"$T/skills" ;;
    pair)
      printf '%s\t\n' "${S}PROFILE${S}NAME${S}TYPE${S}LAYER${S}NOW"
      while IFS= read -r p; do
        while IFS=$'\t' read -r n l k _; do
          printf '%s\t%s\n' "$(s_mark pair "$n"$'\t'"$p")$S$(s_pname "$p")$S$n$S$k$S$C_DIM$l$C_RESET$S$(s_have "$n" "$p" && echo "$C_GREEN✓$C_RESET" || echo "$C_DIM–$C_RESET")" "$n|$p"
        done <"$T/skills"
      done <"$T/prof" ;;
    prof)
      printf '%s\t\n' "${S}PROFILE${S}FOLDER${S}HAS"
      while IFS= read -r p; do
        local c=0 k=0
        while IFS= read -r n; do (( k++ )); s_have "$n" "$p" && (( c++ )); done <"$T/on.skill"
        printf '%s\t%s\n' "$(s_mark prof "$p")$S$(s_pname "$p")$S$C_DIM${p/#$HOME/\~}$C_RESET$S$c of the $k picked" "$p"
      done <"$T/prof" ;;
  esac
}
s_layout() {
  local v; v=$(s_rows | print_table 3 "$(ui_pick_width)")
  printf '%s\n' "${v%%$'\n'*}" >"$T/title"; tail -n +2 <<<"$v" >"$T/rows"
}
s_keys() {
  case $(s_view) in
    skill) if (( $(s_np) > 1 )); then echo "tab: tick · alt-g: by profile · enter: then which profiles · ctrl-p: details pane · esc: cancel"
           else echo "tab: tick · alt-g: by profile · enter: apply · ctrl-p: details pane · esc: cancel"; fi ;;
    pair)  echo "tab: tick · alt-g: by skill · enter: apply these · ctrl-p: details pane · esc: cancel" ;;
    prof)  echo "tab: tick · enter: apply · ctrl-p: details pane · esc: back to the skills" ;;
  esac
}
s_about() {
  case $(s_view) in
    skill) echo "# Ticked: in every profile. ◐: in some (unticked: left as it is). Unticking a ✓ one removes it." ;;
    pair)  echo "# A row per profile and skill or plugin: ticked ones are set up, the rest removed." ;;
    prof)  echo "# The profiles that get the picked ones. Unticking one that has them removes them there." ;;
  esac
}
s_header() { ui_sort_keys "$(s_about)"$'\n'"$(s_keys)"; printf '\n%s' "$(cat "$T/title")"; }
s_reload() { s_layout; ip_join "reload-sync(cat '$T/rows')" "$(ui_fz change-header "$(s_header)")" "${1:-first}"; }

s_tick() {   # id index
  [[ $(ip_get mode) == confirm || -z ${1:-} ]] && return 0
  local v id=$1; v=$(s_view)
  [[ $v == pair ]] && id="${1%%|*}"$'\t'"${1#*|}"
  if s_on "$v" "$id"; then grep -vxF "$id" "$T/on.$v" >"$T/x"; mv "$T/x" "$T/on.$v"; else printf '%s\n' "$id" >>"$T/on.$v"; fi
  s_reload "pos($(( $2 + 1 )))"
}

# alt-g: by skill <-> by profile, the ticks carried over
s_group() {
  [[ $(ip_get mode) == confirm ]] && return 0
  local n p
  case $(s_view) in
    skill) s_want >"$T/on.pair"; echo pair >"$T/view" ;;
    pair)  # a skill is ticked when every profile has it ticked
      : >"$T/on.skill"
      while IFS=$'\t' read -r n _; do
        local all=1; while IFS= read -r p; do s_on pair "$n"$'\t'"$p" || { all=0; break; }; done <"$T/prof"
        (( all )) && echo "$n" >>"$T/on.skill"
      done <"$T/skills"
      echo skill >"$T/view" ;;
    *) return 0 ;;
  esac
  s_reload
}

# what should be linked afterwards ("name TAB profile"), from the open view
s_want() {
  local n p v; v=$(s_view)
  if [[ $v == pair ]]; then sort -u "$T/on.pair"; return; fi
  {
    while IFS=$'\t' read -r n p; do   # what's there stays, but for the picked skills and the full ones unticked
      s_on skill "$n" && continue
      grep -qxF "$n" "$T/full" && continue
      printf '%s\t%s\n' "$n" "$p"
    done <"$T/have"
    while IFS= read -r n; do
      while IFS= read -r p; do
        if [[ $v == prof ]]; then s_on prof "$p" && printf '%s\t%s\n' "$n" "$p"
        else printf '%s\t%s\n' "$n" "$p"; fi   # by skill: ticked means in every profile
      done <"$T/prof"
    done <"$T/on.skill"
  } | sort -u
}

# the plan: add and rm; then ask about what goes, or apply
s_finish() {
  s_want >"$T/want"; sort -u "$T/have" >"$T/had"
  comm -13 "$T/had" "$T/want" >"$T/add"; comm -23 "$T/had" "$T/want" >"$T/rm"
  if [[ -s $T/rm ]]; then
    local list n p
    list=$(while IFS=$'\t' read -r n p; do printf '%s (%s), ' "$n" "$(s_pname "$p")"; done <"$T/rm" | sed 's/, $//')
    ip_confirm "Remove $list?" rm n; return
  fi
  touch "$T/go"; echo accept
}

s_key() {
  local a
  if [[ $(ip_get mode) == confirm ]]; then
    a=$(ip_answer "$1"); [[ -n $a ]] || return 0
    if [[ $a == yes ]]; then touch "$T/go"; echo accept; return; fi
    ip_join "$(ip_back)" "$(s_reload "pos(${FZF_POS:-1})")" "$(ui_fz change-footer "Nothing removed: tick them again, or esc to leave")"
    return
  fi
  case $1:$(s_view) in
    esc:prof) echo skill >"$T/view"; s_reload ;;
    esc:*) echo abort ;;
    enter:skill)
      if (( $(s_np) > 1 )) && [[ -s $T/on.skill ]]; then   # then which profiles: those that have them, ticked
        local n p
        : >"$T/on.prof"
        while IFS= read -r p; do
          while IFS= read -r n; do s_have "$n" "$p" && { echo "$p" >>"$T/on.prof"; break; }; done <"$T/on.skill"
        done <"$T/prof"
        echo prof >"$T/view"; s_reload
      else s_finish; fi ;;
    enter:*) s_finish ;;
  esac
}

# ctrl-p: the pane closed -> right -> below -> closed; the hints re-wrap for the room it leaves
s_pane() {
  local next
  case $(cat "$T/pane" 2>/dev/null) in
    right) next=down ;;
    down) next="" ;;
    *) next=right ;;
  esac
  printf '%s' "$next" >"$T/pane"
  case $next in
    right) printf '%s' 'change-preview-window(right,40%,nohidden)' ;;
    down) printf '%s' 'change-preview-window(down,50%,nohidden)' ;;
    *) printf '%s' 'change-preview-window(hidden)' ;;
  esac
  printf '+transform:bash %q header %q\n' "$repo/lib/skills.sh" "$T"
}

# the preview: the skill under the cursor in each profile; on a profile, the picked skills there
s_preview() {
  local id=${1:-} n p d
  [[ -n $id ]] || return 0
  if [[ $(s_view) == prof ]]; then
    printf '%s\n\n' "$C_BOLD$(s_pname "$id")$C_RESET  $C_DIM${id/#$HOME/\~}$C_RESET"
    while IFS= read -r n; do
      if s_have "$n" "$id"; then printf '%s %s\n' "$C_GREEN✓$C_RESET" "$n"; else printf '%s %s\n' "$C_DIM–$C_RESET" "$n"; fi
    done <"$T/on.skill"
    return
  fi
  n=${id%%|*}
  local k src what
  IFS=$'\t' read -r k src what < <(awk -F'\t' -v n="$n" '$1 == n { print $3 "\t" $4 "\t" $5 }' "$T/skills")
  printf '%s\n' "$C_BOLD$n$C_RESET  $C_DIM$k$C_RESET"
  printf '%s\n' "${what:0:300}"
  [[ $k == plugin ]] && printf '%s\n' "${C_DIM}github.com/${src#*|}$C_RESET"
  printf '\n'
  while IFS= read -r p; do
    if s_have "$n" "$p"; then printf '%s %s\n' "$C_GREEN✓$C_RESET" "$(s_pname "$p")"
    else printf '%s %s\n' "$C_DIM–$C_RESET" "$(s_pname "$p")"; fi
  done <"$T/prof"
}

if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then
  repo="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
  . "$repo/lib/ui.sh"; [[ -z "${NO_COLOR:-}" ]] && ui_color
  T=$2 IP=$2
  . "$repo/lib/inplace.sh"
  case $1 in
    layout)   s_layout ;;
    header)   ui_fz change-header "$(s_header)" ;;
    relayout) s_reload "pos(${FZF_POS:-1})" ;;
    tick)     s_tick "${3:-}" "${4:-0}" ;;
    group)    s_group ;;
    key)      s_key "$3" ;;
    preview)  s_preview "${3:-}" ;;
    pane)     s_pane ;;
  esac
fi
