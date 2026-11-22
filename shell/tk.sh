# tk shell hook: lets the tk picker run the chosen command in this shell (so
# okcli and kx can still change this terminal), and adds tab completion.

unalias tk 2>/dev/null
tk() {
  local f rc
  f=$(mktemp "${TMPDIR:-/tmp}/tk.XXXXXX") || return 1
  TK_EVAL_FILE="$f" command tk "$@"
  rc=$?
  if [ -s "$f" ]; then
    # the picker writes one command name; run it here, as if you typed it
    local cmd; cmd=$(head -n1 "$f")
    rm -f "$f"
    case "$cmd" in *[!a-z-]*|"") return 1 ;; esac
    "$cmd"
    return
  fi
  rm -f "$f"
  return $rc
}

# every installer part: the toolkit's own and each layer's (layers/*/components.sh)
_tk_root=$_work_root   # init unsets _work_root once loaded; Tab needs it later
_tk_components() {
  local f
  for f in "$_tk_root/lib/components.sh" "$_tk_root"/layers/*/components.sh; do
    [ -r "$f" ] && sed -n 's/^COMPONENTS+\{0,1\}=(\(.*\))$/\1/p' "$f"
  done
}

# tk and fk (siblings, lib/kit.sh): the first word from the kit's own help page, so a layer's
# subcommands come too; install / uninstall then take the parts
_tk_complete() {
  local cmd="${COMP_WORDS[0]##*/}" cur="${COMP_WORDS[COMP_CWORD]}" words
  if [ "$COMP_CWORD" -eq 1 ]; then
    words=$(command "$cmd" help 2>/dev/null </dev/null | sed 's/\x1b\[[0-9;]*m//g' | sed -n "s/^ *$cmd \([a-z][a-z0-9-]*\).*/\1/p")
  else
    case "${COMP_WORDS[1]}" in
      install|uninstall) words="ls help --dry-run --details --yes --plain $(_tk_components)" ;;
      *) words="" ;;
    esac
  fi
  COMPREPLY=($(compgen -W "$words" -- "$cur"))
}
if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -U +X bashcompinit 2>/dev/null && bashcompinit
fi
complete -F _tk_complete tk 2>/dev/null
complete -F _tk_complete fk 2>/dev/null
