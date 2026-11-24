# The folders unikit keeps your things in were named work-toolkit until 2026-11. This moves
# each one to its unikit name, once: the old name is left as a link to the new folder, so a
# shell or a desktop session that started before still finds it. A dconf setting that
# names a moved look file is pointed at its new place. A line in ws's list naming the repo
# by its old folder, unix-toolkit, is pointed at unikit. POSIX sh: shell/init.sh loads it in
# bash and zsh, lib/setup.sh in the installer. Cheap when there's nothing to move.

_unikit_move() {   # old new
  [ -d "$1" ] && [ ! -L "$1" ] || return 1
  if [ -e "$2" ]; then cp -an "$1/." "$2/" && rm -rf "$1"   # both there: what's new wins
  else mkdir -p "$(dirname "$2")" && mv "$1" "$2"; fi && ln -sfn "$2" "$1"
}

unikit_migrate() {
  _unikit_move "$HOME/.local/state/work-toolkit" "$HOME/.local/state/unikit"
  _unikit_move "$HOME/.config/work-toolkit" "$HOME/.config/unikit"
  _unikit_move "${XDG_CACHE_HOME:-$HOME/.cache}/work-toolkit" "${XDG_CACHE_HOME:-$HOME/.cache}/unikit"
  # the look files (~/.local/share/unikit is where bootstrap puts unikit itself)
  if _unikit_move "$HOME/.local/share/work-toolkit/looks" "$HOME/.local/state/unikit/looks" &&
     command -v dconf >/dev/null 2>&1; then
    dconf dump / 2>/dev/null | awk -v o="$HOME/.local/share/work-toolkit/looks/" -v n="$HOME/.local/state/unikit/looks/" '
      /^\[/ { s = substr($0, 2, length($0) - 2); next }
      index($0, o) && (e = index($0, "=")) {
        v = substr($0, e + 1); out = ""
        while ((i = index(v, o))) { out = out substr(v, 1, i - 1) n; v = substr(v, i + length(o)) }
        printf "/%s/%s\t%s\n", s, substr($0, 1, e - 1), out v
      }' | while IFS='	' read -r _k _v; do dconf write "$_k" "$_v"; done
  fi
  # ws's list: a folder named unix-toolkit that's gone, with a unikit beside it, is the
  # repo under its new name (that list is yours; only those lines change)
  _l="${WS_LIST_FILE:-${XDG_CONFIG_HOME:-$HOME/.config}/ws/workspaces}"
  if [ -f "$_l" ] && grep -q '/unix-toolkit' "$_l"; then
    _changed=
    while IFS= read -r _line || [ -n "$_line" ]; do
      _p=${_line#"${_line%%[![:space:]]*}"}; _p=${_p%%[[:space:]]*}   # the folder
      case $_p in */unix-toolkit|*/unix-toolkit/)
        _o=${_p%/}; case $_o in "~"/*) _o="$HOME${_o#\~}" ;; esac
        if [ ! -e "$_o" ] && [ -d "${_o%/unix-toolkit}/unikit" ]; then
          _line="${_line%%"$_p"*}${_p%/unix-toolkit*}/unikit${_line#*"$_p"}"; _changed=1
        fi ;;
      esac
      printf '%s\n' "$_line"
    done <"$_l" >"$_l.unikit-tmp"
    if [ -n "$_changed" ]; then mv "$_l.unikit-tmp" "$_l"; else rm -f "$_l.unikit-tmp"; fi
  fi
  return 0
}
