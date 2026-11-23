# Tab completion for every unikit and layer command that has no completer of its
# own (tk has its own; a layer may register its commands'). The first word comes from
# the command's help page (the lines "<cmd> <word> ..."), so it never falls behind.
# A command adds the words that come later with a function _work_complete_<cmd>
# (- as _): it reads COMP_WORDS / COMP_CWORD and prints one word per line (spaces
# allowed). Loaded last by shell/init.sh; a layer's commands come from its tools file.
# A layer's shell/init.sh may register one itself (`complete -o default -F _work_complete
# <cmd>` for a command that also takes paths): this file then leaves it alone.

_work_complete() {
  local cmd="${COMP_WORDS[0]##*/}" cur="${COMP_WORDS[COMP_CWORD]}" words="" fn w
  [ "$COMP_CWORD" -eq 1 ] &&
    words=$(command "$cmd" help 2>/dev/null </dev/null | sed -n "s/^ *$cmd \([a-z][a-z0-9-]*\).*/\1/p")
  fn="_work_complete_$(printf '%s' "$cmd" | tr - _)"
  if type "$fn" >/dev/null 2>&1; then words="$words
$("$fn" 2>/dev/null)"; fi
  cur=$(printf '%s' "$cur" | sed 's/\\//g')   # what's typed, escapes taken out ("Media\ A")
  COMPREPLY=()
  while IFS= read -r w; do   # the words that start with it, once each, spaces escaped
    [ -n "$w" ] && case "$w" in "$cur"*) case " ${COMPREPLY[*]} " in *" $(printf '%q' "$w") "*) ;; *) COMPREPLY+=("$(printf '%q' "$w")") ;; esac ;; esac
  done <<EOF
$words
EOF
}

# uk layer: add / rm / ls / check, then rm takes a layer's name; uk skills: ls, help, the skills' names
_work_root_uk=$_work_root   # init unsets _work_root once loaded; Tab needs it later
_work_complete_uk() {
  case "$COMP_CWORD:${COMP_WORDS[1]}" in
    2:layer|2:layers) printf '%s\n' ls add rm check ;;
    3:layer|3:layers) [ "${COMP_WORDS[2]}" = rm ] && command ls -1 "$_work_root_uk/layers" 2>/dev/null ;;
    2:skills) printf '%s\n' ls help
              command ls -1d "$_work_root_uk"/claude/skills/*/ "$_work_root_uk"/layers/*/claude/skills/*/ 2>/dev/null | sed 's|/$||; s|.*/||' ;;
  esac
}

if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -U +X bashcompinit 2>/dev/null && bashcompinit
fi
for _c in uk fk dex $(sed -n 's/^\([a-z][a-z0-9-]*\)|.*/\1/p' "$_work_root"/layers/*/tools 2>/dev/null); do
  if [ -n "${ZSH_VERSION:-}" ]; then
    (( ${+_comps[$_c]} )) && continue
  else
    complete -p "$_c" >/dev/null 2>&1 && continue
  fi
  complete -F _work_complete "$_c" 2>/dev/null
done
unset _c
