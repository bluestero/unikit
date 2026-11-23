# Work shell toolkit: the one file your shell loads. Works in bash and zsh.
#   bash: ~/.bashrc has one line that sources this (install.sh adds it)
#   zsh:  ~/.zshrc has the same line (the zsh-hook part)
#
# Loads, in order: the layers' shell/init.sh (by name, a layer's requires first), then
# unikit's own (tk's hook, Tab completion). Safe to source more than once.

_work_root="$(cd "$(dirname "${BASH_SOURCE[0]:-${(%):-%x}}")/.." && pwd)"

# Layers (lib/layers.sh): extra parts in layers/<name>/, each from its own repo.
# Listed with ls, not a glob: an empty glob is an error in zsh.
# (Loops use $(...) because zsh doesn't split a plain variable into words.)
# Each folder goes in front, so the last one comes first: unikit's own, a layer can't take
# one of its command names (uk doctor names a layer that tries).
# Order: by name, but a layer's requires (its requires file) load before it.
_work_layer_add() {   # name: prints layers/<name> after the ones it requires, each one once
  case "$_work_seen" in *" $1 "*) return 0 ;; esac
  [ -d "$_work_root/layers/$1" ] || return 0
  _work_seen="$_work_seen$1 "
  if [ -r "$_work_root/layers/$1/requires" ]; then
    for _r in $(grep -v '^[[:space:]]*\(#\|$\)' "$_work_root/layers/$1/requires"); do _work_layer_add "$_r"; done
  fi
  echo "layers/$1"
}
_work_layers() {
  _work_seen=" "
  for _n in $(command ls -1 "$_work_root/layers" 2>/dev/null); do _work_layer_add "$_n"; done
}
for _d in $(_work_layers); do
  case ":$PATH:" in *":$_work_root/$_d/bin:"*) ;; *) [ -d "$_work_root/$_d/bin" ] && PATH="$_work_root/$_d/bin:$PATH" ;; esac
done
case ":$PATH:" in *":$_work_root/bin:"*) ;; *) PATH="$_work_root/bin:$PATH" ;; esac
export PATH

# A layer's settings come before the tools, which read them (OKTA_AWSCLI_*, KX_ALIAS_RULES).
for _l in $(_work_layers); do
  [ -r "$_work_root/$_l/shell/init.sh" ] && . "$_work_root/$_l/shell/init.sh"
done


# A blank line before each prompt, except the first one (and the first after
# 'clear'): a new terminal starts on the top line, not one down.
_work_gap() { [ -n "${_work_prompted:-}" ] && echo; _work_prompted=1; }
clear() { command clear "$@"; unset _work_prompted; }
if [ -n "${ZSH_VERSION:-}" ]; then
  autoload -Uz add-zsh-hook && add-zsh-hook precmd _work_gap
elif declare -F starship_precmd >/dev/null; then
  case "${STARSHIP_PROMPT_COMMAND:-}" in *_work_gap*) ;; *)
    STARSHIP_PROMPT_COMMAND="_work_gap${STARSHIP_PROMPT_COMMAND:+;$STARSHIP_PROMPT_COMMAND}" ;; esac
else
  case "${PROMPT_COMMAND:-}" in *_work_gap*) ;; *)
    PROMPT_COMMAND="_work_gap${PROMPT_COMMAND:+;$PROMPT_COMMAND}" ;; esac
fi

for _f in \
  shell/tk.sh \
  shell/complete.sh
do
  [ -r "$_work_root/$_f" ] && . "$_work_root/$_f"
done
unset _f _d _l _work_root; unset -f _work_layers _work_layer_add

# One name per tool (no okp / kctx); old shells may still have them, so drop them.
unalias okp kctx 2>/dev/null
