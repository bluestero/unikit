# What install.sh / uninstall.sh manage. Sourced after lib/setup.sh.
#
# Each component <id> has:
#   label_<id>       short name (summary at the end)
#   title_<id>       one line in plain words: what you get
#   detail_<id>      what it touches on disk (shown with --details)
#   state_<id>       sets STATE (installed | partial | missing | n/a) and NOTE
#   install_<id>     brings it to "installed"; does nothing if already there
#   uninstall_<id>   puts things back; does nothing if already gone
# (<id> with - replaced by _ in function names)
# Whether this machine can run a component at all (GNOME? apt? Linux?) is checked
# first, from requires_of below; state_<id> only covers what's left (n/a there =
# a dependency such as kitty isn't installed yet).

# shellcheck source=platform.sh
. "$repo/lib/platform.sh"
# shellcheck source=layers.sh
. "$repo/lib/layers.sh"

COMPONENTS=(bash zsh-hook commands fzf claude-skill)
# Shown in groups in the checklist; the rest are optional extras.
RECOMMENDED=(bash zsh-hook commands fzf)
# Components with a settings look: naming one that is installed opens the keep / look / defaults menu
LOOK_PARTS=()   # components with a settings menu; a layer adds its own (LOOK_PARTS+=)
CLAUDE_PARTS=(claude-skill)
# Which repo a component comes from: the toolkit, or the layer that adds it (bluefeels, ...).
repo_of() { echo "${LAYER_OF[$1]:-toolkit}"; }
# the layer a part comes from, for the installers' LAYER column (unikit: the base's own)
layer_name() { echo "${LAYER_OF[$1]:-unikit}"; }
# Two layers (or a layer and unikit) setting up the same thing. A part says what it changes
# with touches_<id> (one per line: a file, or dconf:/a/path/); before it changes something a
# part of another layer has set up, the installer asks: skip it (the default; --yes too),
# replace (backups as always), or add both, when the part can sit beside the other (addboth_<id>).
touches_of() { local f; f=$(fn touches "$1"); declare -F "$f" >/dev/null && "$f"; return 0; }
# shared_keep <id>: in an uninstall, true (and says so) when another layer's part has the same thing
# set up (two layers bringing one GNOME extension): asked, default no; --yes and dry runs keep it
shared_keep() {
  local o; o=$(touch_clash "$1") || return 1; o=${o%%$'\t'*}
  if [[ $mode != yes ]] && ask "$o ($(layer_name "$o")) has it set up too. Remove it anyway?" n; then return 1; fi
  ok "left as it is: $o ($(layer_name "$o")) has it set up too"
}
# touch_clash <id>: "part TAB thing" for each set-up part of another layer that changes what it does; 1 when none
touch_clash() {
  local id=$1 o t mine rc=1 STATE NOTE NEED
  mine=$(touches_of "$id"); [[ -n $mine ]] || return 1
  for o in "${COMPONENTS[@]}"; do
    [[ $o == "$id" || $(layer_name "$o") == "$(layer_name "$id")" ]] && continue
    while IFS= read -r t; do
      [[ -n $t ]] && grep -qxF -- "$t" <<<"$mine" || continue
      component_state "$o" >/dev/null 2>&1
      [[ $STATE == installed || $STATE == partial ]] && { printf '%s\t%s\n' "$o" "$t"; rc=0; }
    done < <(touches_of "$o")
  done
  return "$rc"
}
group_of() {
  # a layer's component names its own group (group_<id>)
  if declare -F "$(fn group "$1")" >/dev/null; then "$(fn group "$1")"
  elif [[ " ${RECOMMENDED[*]} " == *" $1 "* ]]; then echo Recommended
  elif [[ " ${CLAUDE_PARTS[*]} " == *" $1 "* ]]; then echo "Claude Code"
  else echo Optional; fi
}
# One line on what each group is, on top of its tab in the installer; a layer adds its own
# groups' (GROUP_ABOUT[AirPR]=...).
declare -gA GROUP_ABOUT=(
  [Recommended]="The basics: unikit and its layers in bash and zsh, their commands, a newer fzf."
  ["Claude Code"]="Claude Code: your layers' skills, hooks and guidelines, in every Claude profile."
)

# What a component needs from the machine itself (see lib/platform.sh). Anything
# not listed works wherever bash does. A component whose needs aren't met gets
# the state "unsupported" with the reason, and is left out of the setup list.
#   linux  Linux-only download or tool        gnome  GNOME session (gsettings, extensions)
#   apt    installs packages with apt
requires_of() {
  # a layer's component names its own needs (requires_<id>)
  if declare -F "$(fn requires "$1")" >/dev/null; then "$(fn requires "$1")"; return; fi
  case "$1" in
    fzf) echo "linux" ;;
  esac
}
# component_unsupported <id>: the reason this machine can't run it; nothing when it can.
component_unsupported() {
  local need why
  for need in $(requires_of "$1"); do
    why=$(unmet_requirement "$need"); [[ -n $why ]] && { echo "$why"; return 0; }
  done
  return 0
}
# Parts that need another part set up first (a layer adds its own: NEEDS[id]=...).
# One whose needs aren't set up yet is "needs" and can still be picked: picking it
# picks what it needs too (lib/tabs.sh), and the run sets that up first (install.sh).
declare -A NEEDS=()
# component_state <id>: sets STATE and NOTE (unsupported here, else the component's own
# check), and NEED: the parts it needs that aren't set up yet (STATE=needs).
component_state() {
  local why d st nt need=""
  why=$(component_unsupported "$1")
  if [[ -n $why ]]; then STATE=unsupported NOTE=$why NEED=""; return; fi
  "$(fn state "$1")"
  NEED=""
  [[ $STATE == n/a && -n ${NEEDS[$1]:-} ]] || return 0
  st=$STATE nt=$NOTE
  for d in ${NEEDS[$1]}; do
    component_state "$d"
    case $STATE in
      installed) ;;
      unsupported) STATE=unsupported NOTE="needs $d, which can't run here: $NOTE" NEED=""; return ;;
      n/a) STATE=n/a NOTE="needs $d, which $NOTE" NEED=""; return ;;
      *) need+="${need:+ }$d" ;;
    esac
  done
  if [[ -n $need ]]; then STATE=needs NOTE="needs ${need// / and }: picking it picks that too" NEED=$need
  else STATE=$st NOTE=$nt NEED=""; fi
}

fn() { printf '%s_%s' "$1" "${2//-/_}"; }
ver_lt() { [[ "$1" != "$2" && "$(printf '%s\n%s\n' "$1" "$2" | sort -V | head -1)" == "$1" ]]; }

init_line="[ -f \"$repo/shell/init.sh\" ] && . \"$repo/shell/init.sh\"  # work toolkit (unikit)"
init_re='^\[ -f "[^"]*/shell/init\.sh" \] && \. "[^"]*/shell/init\.sh".*# work toolkit'

# ---------------------------------------------------------------- bash ---
# unikit's own: ~/.bashrc loads shell/init.sh (and so every layer) with one line. A look layer
# may tidy the rest of ~/.bashrc (bluefeels' bashrc-tidy).
rc="$HOME/.bashrc"
label_bash() { echo "Bash setup"; }
title_bash() { echo "unikit and its layers in every bash terminal"; }
detail_bash() { echo "~/.bashrc loads unikit with one line"; }
touches_bash() { echo "$rc"; }
state_bash() {
  NOTE=""
  [[ -f "$rc" ]] || { STATE=missing; NOTE="no ~/.bashrc"; return; }
  if grep -qxF "$init_line" "$rc"; then STATE=installed
  elif grep -qE "$init_re" "$rc"; then STATE=partial; NOTE="its line is out of date (another folder, or an older one)"
  else STATE=missing; fi
}
install_bash() {
  local b tmp
  [[ -f "$rc" ]] && grep -qxF "$init_line" "$rc" && { ok "already there"; return; }
  if grep -qE "$init_re" "$rc" 2>/dev/null; then
    ask "Update ~/.bashrc's unikit line (this folder, the current form)?" || { skip; return; }
    dry && return
    b=$(backup "$rc"); tmp=$(mktemp)
    awk -v re="$init_re" -v l="$init_line" '$0 ~ re { if (!done) print l; done = 1; next } { print }' "$rc" >"$tmp"
    cat "$tmp" >"$rc"; rm -f "$tmp"; ok "done (backup: ${b/#$HOME/\~})"
  else
    ask "Add unikit's line to ~/.bashrc?" || { skip; return; }
    dry && return
    [[ -f "$rc" ]] && b=$(backup "$rc")
    printf '\n%s\n' "$init_line" >>"$rc"; ok "done${b:+ (backup: ${b/#$HOME/\~})}"
  fi
}
uninstall_bash() {
  local b tmp
  grep -qE "$init_re" "$rc" 2>/dev/null || { ok "not loaded from ~/.bashrc"; return; }
  b=$(backup "$rc"); tmp=$(mktemp)
  grep -vE "$init_re" "$rc" | cat -s >"$tmp"; cat "$tmp" >"$rc"; rm -f "$tmp"
  ok "removed unikit's line (backup: ${b/#$HOME/\~})"
  warn "bash no longer loads unikit and its layers."
}

# ------------------------------------------------------------ commands ---
cmd_bins=(bin/uk bin/tk bin/fk)
# the long names: links to the short ones, made only where no other program has the name
declare -A cmd_long=([unikit]=bin/uk [toolkit]=bin/tk [feelkit]=bin/fk)
# cmd_taken <name>: the other program that has that name (not ours or a layer's), or 1
cmd_taken() {   # like type -P, without a subshell: tk ls checks every layer command
  local d f="" IFS=:
  for d in $PATH; do [[ -n $d && -f $d/$1 && -x $d/$1 ]] && { f=$d/$1; break; }; done
  [[ -n $f && $f != "$repo"/* ]] || return 1
  [[ -L $f && $(readlink -f "$f") == "$repo"/* ]] && return 1
  printf '%s' "${f/#$HOME/\~}"
}
# cmd_layer_bins: the layers' commands (their bin/, repo-relative), one per line; not a name
# unikit or an earlier layer already has
cmd_layer_bins() {
  local f n seen=" ${cmd_bins[*]##*/} "
  for f in "$repo"/layers/*/bin/*; do
    [[ -f $f && -x $f ]] || continue
    n=${f##*/}; [[ $seen == *" $n "* ]] && continue
    seen+="$n "; printf '%s\n' "${f#"$repo"/}"
  done
}
label_commands() { echo "Toolkit commands"; }
title_commands() { echo "uk, tk, fk and the layers' commands, usable from anywhere"; }
detail_commands() { echo "uk, tk, fk and every layer's bin/ commands (not tk-/fk- subcommands) in ~/.local/bin (for scripts and other programs); unikit, toolkit, feelkit too; a name another program has is left alone"; }
state_commands() {
  local b n=0 total=${#cmd_bins[@]} l
  for b in "${cmd_bins[@]}"; do linked "$HOME/.local/bin/${b##*/}" "$repo/$b" && (( n++ )); done
  for l in "${!cmd_long[@]}"; do   # a long name another program has counts as done
    cmd_taken "$l" >/dev/null && ! linked "$HOME/.local/bin/$l" "$repo/${cmd_long[$l]}" && continue
    (( total++ )); linked "$HOME/.local/bin/$l" "$repo/${cmd_long[$l]}" && (( n++ ))
  done
  while IFS= read -r b; do   # same for a layer's command
    l=${b##*/}
    if linked "$HOME/.local/bin/$l" "$repo/$b"; then (( total++, n++ ))
    elif ! cmd_taken "$l" >/dev/null; then (( total++ )); fi
  done < <(cmd_layer_bins)
  NOTE=""
  if (( n == total )); then STATE=installed
  elif (( n )); then STATE=partial; NOTE="$n of $total linked"
  else STATE=missing; fi
}
install_commands() {
  local b b2 name other
  for b in "${cmd_bins[@]}"; do
    name=${b##*/}
    linked "$HOME/.local/bin/$name" "$repo/$b" && continue
    chmod +x "$repo/$b"
    if ask "Add the ${B}$name${R} command?"; then link_file "$HOME/.local/bin/$name" "$repo/$b"; else skip; fi
  done
  for name in unikit toolkit feelkit; do
    b=${cmd_long[$name]}
    linked "$HOME/.local/bin/$name" "$repo/$b" && continue
    if other=$(cmd_taken "$name"); then   # never taken over without asking, --yes included
      skip "${B}$name${R} is already $other"; continue
    fi
    if ask "Add ${B}$name${R} (the long name of ${b##*/})?"; then link_file "$HOME/.local/bin/$name" "$repo/$b"; else skip; fi
  done
  while IFS= read -r b; do
    name=${b##*/}
    linked "$HOME/.local/bin/$name" "$repo/$b" && continue
    if other=$(cmd_taken "$name"); then skip "${B}$name${R} is already $other"; continue; fi
    b2=${b#layers/}
    if ask "Add the ${B}$name${R} command (from ${b2%%/*})?"; then link_file "$HOME/.local/bin/$name" "$repo/$b"; else skip; fi
  done < <(cmd_layer_bins)
  case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) warn "~/.local/bin is not on your PATH" ;; esac
}
uninstall_commands() {
  local b l
  for b in "${cmd_bins[@]}"; do
    points_at "$HOME/.local/bin/${b##*/}" "$repo/$b" && rm -f "$HOME/.local/bin/${b##*/}" && ok "removed ${b##*/}"
  done
  for l in "${!cmd_long[@]}"; do
    points_at "$HOME/.local/bin/$l" "$repo/${cmd_long[$l]}" && rm -f "$HOME/.local/bin/$l" && ok "removed $l"
  done
  while IFS= read -r b; do
    points_at "$HOME/.local/bin/${b##*/}" "$repo/$b" && rm -f "$HOME/.local/bin/${b##*/}" && ok "removed ${b##*/}"
  done < <(cmd_layer_bins)
  return 0
}

# ----------------------------------------------------------------- fzf ---
# Every toolkit picker runs on fzf. A current release in ~/.local/bin (ahead of
# apt's on PATH) gives the lists a position counter and k-theme its tabs.
fzf_mine="$HOME/.local/bin/fzf"
fzf_ver() { "${1:-fzf}" --version 2>/dev/null | awk '{print $1}'; }
label_fzf() { echo "fzf (current)"; }
title_fzf() { echo "Newer fzf for every picker: shows where you are (12/426), k-theme's tabs"; }
detail_fzf() { echo "fzf $FZF_VERSION from GitHub (checksum-checked) in ~/.local/bin; apt's fzf, if any, stays as the fallback"; }
state_fzf() {
  local v; v=$(fzf_ver); NOTE=""
  if [[ -z "$v" ]]; then STATE=missing
  elif ver_lt "$v" "$FZF_MIN"; then STATE=partial; NOTE="now: $v (too old for the counter and k-theme tabs)"
  elif [[ -x "$fzf_mine" ]] && ver_lt "$(fzf_ver "$fzf_mine")" "$FZF_VERSION"; then STATE=partial; NOTE="update: $(fzf_ver "$fzf_mine") → $FZF_VERSION"
  else STATE=installed; NOTE="$v"; fi
}
install_fzf() {
  local v; v=$(fzf_ver "$fzf_mine")
  if [[ -n "$v" ]] && ! ver_lt "$v" "$FZF_VERSION"; then ok "fzf $v"; return; fi
  if ask "Download fzf $FZF_VERSION into ~/.local/bin? (about 2 MB, no sudo)"; then
    dry && return
    fetch_fzf && ok "fzf $(fzf_ver "$fzf_mine")" || fail "not installed (see the log)"
  else skip; fi
  case "$(type -P fzf)" in "$fzf_mine"|"") ;; *) warn "$(type -P fzf) comes first on PATH; open a new terminal" ;; esac
}
uninstall_fzf() {
  [[ -e "$fzf_mine" ]] || { ok "not installed"; return 0; }
  rm -f "$fzf_mine"
  if type -P fzf >/dev/null; then ok "removed; back to $(type -P fzf) $(fzf_ver)"
  else ok "removed (no other fzf: pickers fall back to plain lists)"; fi
}

# ------------------------------------------------------------ zsh-hook ---
# unikit's own: ~/.zshrc loads shell/init.sh (and so every layer), like bash's line.
zsh_hook_body="[ -f \"$repo/shell/init.sh\" ] && . \"$repo/shell/init.sh\""
# what the zsh part used to put there (unikit's zsh/zshrc, now gone): set up again to replace it
zsh_hook_old="[ -f \"$repo/zsh/zshrc\" ] && . \"$repo/zsh/zshrc\""
# GNOME starts the session through the login shell; zsh doesn't read ~/.profile
# on its own, so flatpak apps and ~/.local/bin would go missing without this.
zprofile_body="[ -f ~/.profile ] && emulate sh -c '. ~/.profile'"
label_zsh_hook() { echo "Zsh setup"; }
title_zsh_hook() { echo "unikit and its layers in every zsh terminal"; }
detail_zsh_hook() { echo "~/.zshrc loads unikit with one line; ~/.zprofile reads ~/.profile (PATH, flatpak apps)"; }
touches_zsh_hook() { echo "$HOME/.zshrc"; echo "$HOME/.zprofile"; }
state_zsh_hook() {
  local n=0
  has_block "$HOME/.zshrc" "$zsh_hook_body" && (( n++ ))
  has_block "$HOME/.zprofile" "$zprofile_body" && (( n++ ))
  NOTE=""
  if (( n == 2 )); then STATE=installed
  elif has_block "$HOME/.zshrc" "$zsh_hook_old"; then STATE=partial; NOTE="~/.zshrc has the older line: set up again to replace it"
  elif (( n )); then STATE=partial
  else STATE=missing; fi
}
install_zsh_hook() {
  if has_block "$HOME/.zshrc" "$zsh_hook_body" && has_block "$HOME/.zprofile" "$zprofile_body"; then
    ok "already set up"; return; fi
  if ask "Set up ~/.zshrc and ~/.zprofile (one managed block each) to load unikit?"; then
    set_block "$HOME/.zshrc" "$zsh_hook_body"
    set_block "$HOME/.zprofile" "$zprofile_body"
    ok "done"
  else skip; fi
}
uninstall_zsh_hook() {
  drop_block "$HOME/.zshrc"; drop_block "$HOME/.zprofile"
  ok "removed unikit from ~/.zshrc and ~/.zprofile"
}

# ------------------------------------------------------------- looks ---
# A "look" is a preset of an extension's settings (gnome/<name>/settings.dconf, a dconf dump).
# Installing asks whether to use it; the settings from before are kept once and the uninstall
# offers them back, or the app's own defaults (dconf reset).
# look_applied PATH FILE [IGNORE] [NAME]: every setting in FILE is the same live (keys matching the
# IGNORE regex are skipped: Dash to Panel stores panel keys per monitor).
# Your patch (~/.config/unikit/patches/<NAME>.dconf) is loaded after the look, so its
# settings win; the toolkit never writes to it except when you ask (keep my changes as my patch).
look_patch() { printf '%s' "$HOME/.config/unikit/patches/$1.dconf"; }
# Files a look points at (@HERE@/<file>: an icon) are copied out of the repo, so the setting
# outlives a moved toolkit or a removed layer; look_copy is where they go.
look_copy() { printf '%s' "$HOME/.local/state/unikit/looks/$(basename "$(dirname "$1")")"; }
look_refs() { grep -o "@HERE@/[^'\"]*" "$1" 2>/dev/null | sed 's#^@HERE@/##' | sort -u; }
look_copied() { local f; for f in $(look_refs "$1"); do cmp -s "$(dirname "$1")/$f" "$(look_copy "$1")/$f" || return 1; done; }
look_file() { sed "s#@REPO@#$repo#; s#@HERE@#$(look_copy "$1")#" "$1"; }   # the look, its paths filled in
look_applied() {   # look_applied PATH FILE [IGNORE] [NAME: with its patch]  (a missing look is never applied)
  [[ -s $2 ]] && look_copied "$2" || return 1
  python3 -I "$repo/lib/dconf_patch.py" applied "${3:-}" <(dconf dump "$1" 2>/dev/null) <(look_file "$2") \
    ${4:+"$(look_patch "$4")"}
}
look_apply() {   # look_apply PATH FILE NAME
  [[ -s $2 ]] || { fail "the look ${2#"$repo"/} is missing, so nothing was applied"; return 1; }
  local f; for f in $(look_refs "$2"); do mkdir -p "$(look_copy "$2")" && cp "$(dirname "$2")/$f" "$(look_copy "$2")/$f"; done
  mkdir -p "$orig_dir"
  [[ -f "$orig_dir/$3.dconf" ]] || dconf dump "$1" >"$orig_dir/$3.dconf" 2>/dev/null
  look_file "$2" | dconf load "$1"
  [[ -f $(look_patch "$3") ]] && dconf load "$1" <"$(look_patch "$3")"
  return 0
}
look_reset() {   # look_reset PATH NAME: the app's defaults, or your settings from before the toolkit
  dry && return 0
  local f="$orig_dir/$2.dconf"
  dconf reset -f "$1"
  if grep -q = "$f" 2>/dev/null && ask "Put your own earlier $2 settings back? (No: the app's own defaults)"; then
    dconf load "$1" <"$f" && ok "your earlier settings are back"
  else ok "$2 settings back to the app's defaults"; fi
  rm -f "$f" "$orig_dir/$2.last.dconf"
}
look_note() {   # look_note PATH BEFORE: what the last action changed, in words
  local n; n=$(diff <(printf '%s\n' "$2") <(dconf dump "$1" 2>/dev/null) | sed -n 's/^[<>] \([^=]*\)=.*/\1/p' | sort -u | wc -l)
  if (( n )); then printf '%s setting%s changed' "$n" "$([[ $n == 1 ]] || echo s)"; else printf 'nothing changed'; fi
}
# look_menu PATH FILE NAME NICE [IGNORE]: what to do with the settings of an extension that
# is already installed: keep, re-apply the toolkit look, reset to the app's defaults, put back
# the settings from before the toolkit, or (when a copy exists) undo the last change. Each says
# how many settings it changed; the settings from just before a change are kept once.
LOOK_KEEP="Keep my settings"; LOOK_APP="Re-apply the toolkit look"; LOOK_RST="Reset to the app's defaults"
LOOK_UND="Undo the last change"; LOOK_PRE="Put back my settings from before the toolkit"
LOOK_KPT="Keep my changes as my patch"; LOOK_DRP="Drop my patch"
# look_choices NAME [differs]: the menu's choices, one per line (the ones after the first three only
# when there is something for them: settings that differ from the look, a patch, a copy to go back to)
look_choices() {
  printf '%s\n%s\n%s\n' "$LOOK_KEEP" "$LOOK_APP" "$LOOK_RST"
  [[ -n ${2:-} ]] && printf '%s\n' "$LOOK_KPT"
  [[ -f $(look_patch "$1") ]] && printf '%s\n' "$LOOK_DRP"
  grep -q = "$orig_dir/$1.dconf" 2>/dev/null && printf '%s\n' "$LOOK_PRE"
  [[ -f "$orig_dir/$1.last.dconf" ]] && printf '%s\n' "$LOOK_UND"
  return 0
}
# look_do PATH FILE NAME NICE PICK [IGNORE]: does a choice (no questions; asking first is the caller's job)
look_do() {
  local path=$1 file=$2 name=$3 nice=$4 pick=$5 last="$orig_dir/$3.last.dconf" first="$orig_dir/$3.dconf" before
  before=$(dconf dump "$path" 2>/dev/null)
  case "$pick" in
    "$LOOK_APP") mkdir -p "$orig_dir"; printf '%s\n' "$before" >"$last"
            look_apply "$path" "$file" "$name" && ok "$nice look applied ${D}($(look_note "$path" "$before"); the menu can undo it)${R}" ;;
    "$LOOK_RST") mkdir -p "$orig_dir"; printf '%s\n' "$before" >"$last"
            dconf reset -f "$path" && ok "$nice settings back to the app's defaults ${D}($(look_note "$path" "$before"); the menu can undo it)${R}" ;;
    "$LOOK_PRE") mkdir -p "$orig_dir"; printf '%s\n' "$before" >"$last"
            dconf reset -f "$path"; dconf load "$path" <"$first" &&
              ok "$nice settings back to how they were before the toolkit ${D}($(look_note "$path" "$before"); the menu can undo it)${R}" ;;
    "$LOOK_KPT") local pf; pf=$(look_patch "$name"); mkdir -p "${pf%/*}"
            python3 -I "$repo/lib/dconf_patch.py" diff "${6:-}" <(printf '%s\n' "$before") <(look_file "$file") >"$pf" &&
              ok "$nice: your changes are your patch now ${D}(${pf/#$HOME/\~}; re-applying the look keeps them)${R}" ;;
    "$LOOK_DRP") mkdir -p "$orig_dir"; printf '%s\n' "$before" >"$last"; mv "$(look_patch "$name")" "$(look_patch "$name").dropped"
            look_apply "$path" "$file" "$name" && ok "$nice: patch dropped, the plain look is back ${D}($(look_note "$path" "$before"); the menu can undo it)${R}" ;;
    "$LOOK_UND") dconf reset -f "$path"; dconf load "$path" <"$last" && rm -f "$last" &&
              ok "$nice settings back to before the last change ${D}($(look_note "$path" "$before"))${R}" ;;
    *) ok "$nice settings kept" ;;
  esac
}
look_menu() {
  local path=$1 file=$2 name=$3 nice=$4 ign=${5:-} state pick q rows
  local differs=""
  if look_applied "$path" "$file" "$ign" "$name"; then state="match the toolkit look"; else state="differ from the toolkit look"; differs=1; fi
  [[ -f $(look_patch "$name") ]] && state+=" (with your patch)"
  case "$mode" in
    dry) say "  ${C}?${R} $nice settings $state ${D}(dry run: not asked)${R}"; return 0 ;;
    yes) look_applied "$path" "$file" "$ign" "$name" && { ok "look already applied"; return 0; }; pick=$LOOK_APP ;;
    *)
      if ! type -P fzf >/dev/null || [[ ! -t 0 ]]; then ok "$nice settings kept"; return 0; fi
      rows=$(look_choices "$name" "$differs")
      q="${C_BOLD}$nice settings $state${C_RESET}"
      pick=$(printf '%s\n' "$rows" | ui_fzf "${UI_CONFIRM_LABEL:-settings}" --height=~60% --info=hidden \
        --no-separator --prompt='  ' --header="$q") || pick=$LOOK_KEEP ;;
  esac
  if [[ $pick == "$LOOK_RST" ]]; then ask "Reset $nice to the app's defaults? (the menu can undo it)" n || { skip; return 0; }; fi
  look_do "$path" "$file" "$name" "$nice" "$pick" "$ign"
}
# A GNOME extension from extensions.gnome.org plus its look. gx_state UUID PATH FILE [IGNORE];
# gx_install UUID NAME PATH FILE [IGNORE]
gx_present() { [[ -d "$HOME/.local/share/gnome-shell/extensions/$1" ]]; }
gx_enabled() { gsettings get org.gnome.shell enabled-extensions 2>/dev/null | grep -q "'$1'"; }
gx_state() {
  NOTE=""
  if gx_present "$1" && gx_enabled "$1"; then
    if look_applied "$2" "$3" "${4:-}" "$1"; then STATE=installed; else STATE=partial; NOTE="settings differ from the toolkit's look"; fi
  elif gx_present "$1" || gx_enabled "$1"; then STATE=partial; NOTE="installed, not enabled"
  else STATE=missing; fi
}
gx_install() {
  local uuid=$1 name=$2
  if gx_present "$uuid" && gx_enabled "$uuid"; then look_menu "$3" "$4" "$uuid" "$name" "${5:-}"; return; fi
  if ! gx_present "$uuid"; then
    ask "Download $name from extensions.gnome.org and install it?" || { skip; return 0; }
    ext_download "$uuid" "$name" || return 1
  fi
  if ! gx_enabled "$uuid"; then
    dry || ext_list add "$uuid"
    ok "enabled"; warn "log out and back in once (Wayland loads new extensions only at login)"
  fi
  if look_applied "$3" "$4" "${5:-}" "$uuid"; then ok "look already applied"
  elif ask "Use the toolkit's look for $name? (your current settings are kept for the uninstall)"; then
    look_apply "$3" "$4" "$uuid" && ok "look applied"
  else skip "keeping your settings"; fi
}
gx_uninstall() {
  gx_present "$1" || { ok "not installed"; return; }
  ext_list del "$1"
  gnome-extensions disable "$1" >/dev/null 2>&1
  gnome-extensions uninstall "$1" >/dev/null 2>&1 || rm -rf "$HOME/.local/share/gnome-shell/extensions/$1"
  ok "$2 removed"
  look_reset "$3" "$1"
}

# ---------------------------------------------------- extension helpers ---
ext_is_on() { gnome-extensions list --enabled 2>/dev/null | grep -qx "$1"; }
# ext_download UUID NAME: fetch the release for this GNOME from extensions.gnome.org and install it
ext_download() {
  local ver url tmp
  ver=$(gnome-shell --version | grep -oE '[0-9]+' | head -1)
  url=$(curl -fsS "https://extensions.gnome.org/extension-info/?uuid=$1&shell_version=$ver" |
    python3 -Ic 'import json,sys; print(json.load(sys.stdin)["download_url"])' 2>/dev/null)
  [[ -n "$url" ]] || { fail "no $2 release for GNOME $ver"; return 1; }
  tmp=$(mktemp --suffix=.zip)
  if curl -fsSL -o "$tmp" "https://extensions.gnome.org$url" && gnome-extensions install --force "$tmp" >>"$log_file" 2>&1; then
    ok "installed"; logf "  from https://extensions.gnome.org$url"
  else rm -f "$tmp"; fail "download or install failed (see the log)"; return 1; fi
  rm -f "$tmp"
}
# GNOME's list of enabled extensions, and custom keyboard shortcuts (layers' parts use them)
ext_list() { # ext_list add|del UUID: edit GNOME's list of enabled extensions
  # add also takes the extension off GNOME's disabled list, which wins over the enabled one
  # (an earlier uninstall puts it there)
  python3 -I -c '
import ast, subprocess, sys
def get(key):
    cur = subprocess.run(["gsettings", "get", "org.gnome.shell", key], capture_output=True, text=True).stdout.strip()
    return ast.literal_eval(cur.removeprefix("@as ")) if cur else []
def put(key, value):
    subprocess.run(["gsettings", "set", "org.gnome.shell", key, str(value)], check=True)
op, uuid = sys.argv[1], sys.argv[2]
lst = get("enabled-extensions")
new = lst + [uuid] if op == "add" and uuid not in lst else [x for x in lst if not (op == "del" and x == uuid)]
if new != lst:
    put("enabled-extensions", new)
if op == "add":
    off = get("disabled-extensions")
    if uuid in off:
        put("disabled-extensions", [x for x in off if x != uuid])
' "$1" "$2"
}
kb_base=/org/gnome/settings-daemon/plugins/media-keys
kb_root=org.gnome.settings-daemon.plugins.media-keys
kb_schema=$kb_root.custom-keybinding
kb_set() { # kb_set ID NAME COMMAND BINDING
  local path="$kb_base/custom-keybindings/$1/" cur
  gsettings set "$kb_schema:$path" name "$2"; gsettings set "$kb_schema:$path" command "$3"; gsettings set "$kb_schema:$path" binding "$4"
  cur=$(gsettings get $kb_root custom-keybindings)
  [[ "$cur" == *"'$path'"* ]] && return 0
  if [[ "$cur" == *"[]"* ]]; then cur="['$path']"; else cur="${cur%]}, '$path']"; fi
  gsettings set $kb_root custom-keybindings "$cur"
}
kb_has() { gsettings get $kb_root custom-keybindings | grep -q "'$kb_base/custom-keybindings/$1/'"; }
# kb_runs ID COMMAND: the shortcut exists and runs COMMAND (false after the toolkit folder moved)
kb_runs() { kb_has "$1" && [[ $(gsettings get "$kb_schema:$kb_base/custom-keybindings/$1/" command) == "'$2'" ]]; }
kb_del() {
  local path="$kb_base/custom-keybindings/$1/" cur
  cur=$(gsettings get $kb_root custom-keybindings)
  cur=$(python3 -I -c 'import ast,sys; print([x for x in ast.literal_eval(sys.argv[1].removeprefix("@as ")) if x != sys.argv[2]])' "$cur" "$path")
  gsettings set $kb_root custom-keybindings "$cur"; dconf reset -f "$path"
}

# ----------------------------------------------------------- workspaces ---
# The workspace list (lib/workspaces.sh): your own (~/.config/ws/workspaces) plus the layers'
# shared lists; its variables (AIRPR=...) name folders layers' parts and commands use.
# shellcheck source=workspaces.sh
. "$repo/lib/workspaces.sh"
# ask_ws_folder NAME "<what goes there>": when the folder a workspace variable
# names ($ACME, ...) doesn't exist yet, show where it would go and let you keep
# that or type another (~/..., /..., or a path inside your home folder), then
# create it and save it in your list. 0 = the folder is there now.
ask_ws_folder() {
  local name=$1 what=$2 cur dir
  cur=$(ws_var "$name")
  [[ -n $cur && -d $cur ]] && return 0
  [[ -n $cur ]] && cur=${cur/#$HOME/\~} || cur="~/$name"
  while :; do
    ask_text "Folder for $what (\$$name)? Enter keeps it; type another to change it" "$cur" || { skip; return 1; }
    dir=$ANSWER
    [[ $dir == "~" || $dir == "~/"* ]] && dir="$HOME${dir:1}"
    [[ $dir == /* ]] || dir="$HOME/$dir"
    dir=$(realpath -m -- "$dir")
    if [[ -z $ANSWER || $ANSWER == *$'\t'* ]]; then warn "that isn't a folder path"
    elif [[ $dir == / || $dir == "$HOME" ]]; then warn "pick a folder of its own, not ${dir/#$HOME/\~}"
    elif [[ -e $dir && ! -d $dir ]]; then warn "${dir/#$HOME/\~} is a file, not a folder"
    elif dry; then say "      ${D}would create ${dir/#$HOME/\~} and save $name there in your list${R}"; return 0
    elif ! mkdir -p -- "$dir" 2>/dev/null; then warn "can't create ${dir/#$HOME/\~} (no permission?)"
    else
      ws_set_var "$name" "$dir"
      ok "$name → ${dir/#$HOME/\~} ${D}(saved in $(ws_list_file | sed "s|^$HOME|~|"); ws edit changes it)${R}"
      return 0
    fi
    [[ $mode == yes ]] && return 1   # --yes can't ask again
    cur=$ANSWER
  done
}

# ----------------------------------------------- what the tools run on ---
# Programs from their releases (what the layers' commands run on): the newest release for
# this CPU, in ~/.local (no sudo). One that's already installed some other way (apt, brew,
# by hand) counts and is left alone.
# ver_of <program>: its version number; a part's ver_<program> (- as _) when --version isn't it
ver_of() {
  local f; f=$(fn ver "${1##*/}")
  if declare -F "$f" >/dev/null; then "$f" "$1"; else "$1" --version; fi 2>/dev/null | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1
}
# tool_state <command>: installed (with version, and where when it isn't ours) or missing
tool_state() {
  local p; p=$(type -P "$1"); NOTE=""
  [[ -n $p ]] || { STATE=missing; return; }
  STATE=installed; NOTE=$(ver_of "$p")
  [[ $p == "$HOME/.local/bin/$1" ]] || NOTE+=" (${p/#$HOME/\~})"
}
# get_tool <command> "<what it's for>" "<size>" <fetch function>
get_tool() {
  local p; p=$(type -P "$1")
  [[ -n $p ]] && { ok "$1 $(ver_of "$p") is already installed"; return; }
  [[ $OS_KIND == linux && -n $(dl_arch) ]] || { skip "no download for this machine; install $1 yourself"; return; }
  ask "Download the latest $1 into ~/.local/bin? ($2; $3, no sudo)" || { skip; return; }
  "$4" && ok "$1 $(ver_of "$HOME/.local/bin/$1")" || fail "not installed (see the log)"
}
# drop_tool <command>: removes ours from ~/.local/bin; one installed another way stays
drop_tool() {
  if [[ -e "$HOME/.local/bin/$1" ]]; then rm -f "$HOME/.local/bin/$1"; ok "removed $1"
  elif type -P "$1" >/dev/null; then ok "$1 wasn't installed by the toolkit ($(type -P "$1")), so it stays"
  else ok "not installed"; fi
}
# gh_tool <owner/repo> <asset> <command>: newest release asset (a tar.gz holding <command>, or the program itself) into ~/.local/bin
gh_tool() {
  local tmp rc=1
  gh_latest "$1" "$2" || { warn "couldn't find the latest $3 (offline?)"; return 1; }
  tmp=$(mktemp -d)
  if fetch_checked "$GH_URL" "$GH_SHA" "$tmp/dl"; then
    if [[ $2 == *.tar.gz ]]; then tar xzf "$tmp/dl" -C "$tmp" "$3" 2>>"$log_file" && mv "$tmp/$3" "$tmp/dl"; fi &&
      mkdir -p "$HOME/.local/bin" && install -m 755 "$tmp/dl" "$HOME/.local/bin/$3" && rc=0
  fi
  rm -rf "$tmp"
  (( rc )) || logf "$3 $GH_VER installed to ~/.local/bin"
  return "$rc"
}

# ---------------------------------------------------------------- apps ---
# Programs a command needs for one of its jobs; the command offers to set its part
# up when it finds it missing (ui_need in lib/ui.sh). One installed another way counts.
# apt_drop <package> "<name>": on uninstall, asks before removing a package (default no)
apt_drop() {
  pkg_installed "$1" || { ok "not installed"; return 0; }
  if ask "Also remove the $2 package? (apt, needs sudo)" n; then
    dry || { as_root apt-get remove -y "$1" >>"$log_file" 2>&1 && ok "package removed" || fail "apt failed (see $log_file)"; }
  else ok "$2 stays"; fi
}

# -------------------------------------------------------------- claude ---
# Claude Code reads its config from $CLAUDE_CONFIG_DIR (a layer may set it, or a folder's .envrc),
# else ~/.claude. claude-skill links the layers' skills; a layer's Claude parts use claude_each and
# claude_state too. They go in every profile: ~/.claude, each one in ~/.claude-profiles/<name> and
# $CLAUDE_CONFIG_DIR.
claude_dir="${CLAUDE_CONFIG_DIR:-$HOME/.claude}"
claude_dirs() {   # every profile folder, one per line (none there yet: where claude will make one)
  local d
  for d in "${CLAUDE_CONFIG_DIR:-}" "$HOME/.claude" "${CLAUDE_PROFILES_DIR:-$HOME/.claude-profiles}"/*/; do
    if [[ -n $d && -d $d ]]; then readlink -m "$d"; fi   # (an && here fails the loop: pipefail then printed the fallback too)
  done | awk '!seen[$0]++' | grep . || { type -P claude >/dev/null && echo "${CLAUDE_CONFIG_DIR:-$HOME/.claude}"; }
  return 0
}
# claude_each <command...>: runs it once per profile, with claude_dir, ch_settings and cg_file set to it
claude_each() {
  local claude_dir ch_settings cg_file rc=0
  while IFS= read -r claude_dir; do
    ch_settings=$claude_dir/settings.json cg_file=$claude_dir/CLAUDE.md
    "$@" || rc=1
  done < <(claude_dirs)
  return "$rc"
}
# claude_state <check...>: STATE over every profile: installed in all, partial (NOTE names the rest)
claude_state() {
  local claude_dir ch_settings cg_file n=0 all=0 miss=""
  while IFS= read -r claude_dir; do
    ch_settings=$claude_dir/settings.json cg_file=$claude_dir/CLAUDE.md; (( all++ ))
    if "$@"; then (( n++ )); else miss+="${miss:+, }${claude_dir/#$HOME/\~}"; fi
  done < <(claude_dirs)
  NOTE=""
  if (( ! all )); then STATE=n/a NOTE="needs Claude Code"
  elif (( n == all )); then STATE=installed
  elif (( n )); then STATE=partial NOTE="not in $miss"
  else STATE=missing; fi
}
cs_pairs() {   # <link><TAB><skill folder>: unikit's skills (none of its own now), then each layer's
  local d
  for d in "$repo"/claude/skills/*/ "$repo"/layers/*/claude/skills/*/; do
    [[ -d $d ]] && printf '%s\t%s\n' "$claude_dir/skills/$(basename "$d")" "${d%/}"
  done
}
cs_has() { local l t; while IFS=$'\t' read -r l t; do linked "$l" "$t" || return 1; done < <(cs_pairs); }
# sk_items: every skill and plugin unikit and its layers bring, "name TAB layer TAB kind TAB
# source TAB what it's for". A skill's source is its folder; a plugin's is plugin@marketplace|
# owner/repo, from a claude/plugins file (a line each: plugin@marketplace|owner/repo|what it gives;
# # comments). A name twice: the first one.
sk_items() {
  local d f n l id src what seen=" "
  for d in "$repo"/claude/skills/*/ "$repo"/layers/*/claude/skills/*/; do
    [[ -d $d ]] || continue
    d=${d%/}; n=${d##*/}
    [[ $seen == *" $n "* ]] && continue; seen+="$n "
    l=unikit; [[ $d == "$repo"/layers/* ]] && { l=${d#"$repo"/layers/}; l=${l%%/*}; }
    printf '%s\t%s\tskill\t%s\t%s\n' "$n" "$l" "$d" "$(sed -n 's/^description: *//p' "$d/SKILL.md" 2>/dev/null | head -1)"
  done
  for f in "$repo"/claude/plugins "$repo"/layers/*/claude/plugins; do
    [[ -r $f ]] || continue
    l=unikit; [[ $f == "$repo"/layers/* ]] && { l=${f#"$repo"/layers/}; l=${l%%/*}; }
    while IFS='|' read -r id src what; do
      [[ $id != \#* && $id == *@* && -n $src ]] || continue   # comments, blank lines
      n=${id%@*}
      [[ $seen == *" $n "* ]] && continue; seen+="$n "
      printf '%s\t%s\tplugin\t%s|%s\t%s\n' "$n" "$l" "$id" "$src" "$what"
    done <"$f"
  done
}
# sk_has <profile> <kind> <name> <source>: that profile has it
sk_has() {
  case $2 in
    skill) linked "$1/skills/$3" "$4" ;;
    plugin) grep -qF "\"${4%%|*}\":" "$1/plugins/installed_plugins.json" 2>/dev/null ;;
  esac
}
# Plugins come from their authors' GitHub repos, each a plugin marketplace; claude plugin update
# keeps them current. cp_add <profile> <plugin@marketplace> <owner/repo>
cp_add() {
  local m=${2#*@}
  if ! grep -qF "\"$m\":" "$1/plugins/known_marketplaces.json" 2>/dev/null; then
    CLAUDE_CONFIG_DIR=$1 claude plugin marketplace add "$3" >>"$log_file" 2>&1 ||
      { fail "couldn't add github.com/$3 to Claude Code in ${1/#$HOME/\~} (see $log_file)"; return 1; }
    remember_setting "claude-marketplace-$m" added   # ours: it goes again with its last plugin
  fi
  CLAUDE_CONFIG_DIR=$1 claude plugin install "$2" >>"$log_file" 2>&1 ||
    { fail "${2%@*} not installed in ${1/#$HOME/\~} (see $log_file)"; return 1; }
}
# cp_rm <profile> <plugin@marketplace>: and its marketplace, when unikit added it and no plugin
# there needs it any more
cp_rm() {
  local m=${2#*@} p
  CLAUDE_CONFIG_DIR=$1 claude plugin uninstall "$2" >>"$log_file" 2>&1 ||
    { fail "couldn't remove ${2%@*} from ${1/#$HOME/\~} (see $log_file)"; return 1; }
  [[ $(recall_setting "claude-marketplace-$m") == added ]] || return 0
  grep -qF "@$m\":" "$1/plugins/installed_plugins.json" 2>/dev/null && return 0
  CLAUDE_CONFIG_DIR=$1 claude plugin marketplace remove "$m" >>"$log_file" 2>&1 ||
    { fail "couldn't remove the $m plugin source from ${1/#$HOME/\~} (see $log_file)"; return 1; }
  while IFS= read -r p; do grep -qF "\"$m\":" "$p/plugins/known_marketplaces.json" 2>/dev/null && return 0; done < <(claude_dirs)
  forget_setting "claude-marketplace-$m"
}
label_claude_skill() { echo "Claude skill"; }
title_claude_skill() { echo "Claude Code knows your layers' commands (their skills) and gets the plugins they list, in every repo"; }
detail_claude_skill() { echo "skills/<name> in each Claude profile links to claude/skills/<name> (and each layer's); a layer's claude/plugins are installed with claude plugin install, picked in the list"; }
state_claude_skill() { claude_state cs_has; }
cs_install() { local l t
  while IFS=$'\t' read -r l t; do
    linked "$l" "$t" && continue
    [[ -e "$l" && ! -L "$l" ]] && { warn "${l/#$HOME/\~} exists and isn't a link; left alone"; continue; }
    ask "Teach Claude Code the $(basename "$l") skill? (in ${claude_dir/#$HOME/\~}/skills)" && { dry || link_file "$l" "$t"; } || skip
  done < <(cs_pairs); }
# In a terminal: a picker of the skills, then the profiles (lib/skills.sh); otherwise one
# question per skill and profile (--yes links them all, a dry run says what it would ask).
install_claude_skill() {
  if [[ $mode == ask && -t 0 && -t 1 ]] && type -P fzf >/dev/null && ui_fzf_at_least 0.63; then
    # shellcheck source=skills.sh
    . "$repo/lib/skills.sh"; sk_pick; return
  fi
  claude_each cs_install
}
cs_uninstall() { local l t n k s
  while IFS=$'\t' read -r l t; do unlink_file "$l" "$t"; done < <(cs_pairs)
  while IFS=$'\t' read -r n _ k s _; do   # the layers' plugins this profile has
    [[ $k == plugin ]] && sk_has "$claude_dir" plugin "$n" "$s" || continue
    dry || { cp_rm "$claude_dir" "${s%%|*}" && ok "$n removed from ${claude_dir/#$HOME/\~}"; }
  done < <(sk_items)
  return 0; }
uninstall_claude_skill() { claude_each cs_uninstall; }

# -------------------------------------------------------------- layers ---
# Each layer's own components (lib/layers.sh), after the toolkit's.
# shellcheck source=layers.sh
. "$repo/lib/layers.sh"
# Parts that shouldn't both be in: "id id|the question" (a layer adds its own; the installer's
# summary asks it once, default No).
CLASHES=()
# Every part belongs to a kit: tk, or fk (lib/layers.sh). A layer's parts go to the kit in its
# "kit" file (tk without one), or to the one a part names with kit_<id>(). ./install.sh sets
# up the tk parts; fk install the fk parts; neither touches the other's.
declare -gA LAYER_OF=() KIT_OF=() LAYER_KIT=()
while IFS= read -r _layer; do
  _n=${#COMPONENTS[@]}
  if [[ -r $_layer/components.sh ]]; then
    # A part name that's taken (unikit's or an earlier layer's) would replace that part's
    # functions: such a layer's parts are left out. Its names are read first, in a subshell.
    _dup=""
    # shellcheck disable=SC1090
    for _id in $( ( COMPONENTS=(); . "$_layer/components.sh" >/dev/null 2>&1; printf '%s\n' "${COMPONENTS[@]}" ) ); do
      [[ " ${COMPONENTS[*]} " == *" $_id "* ]] && _dup+="${_dup:+, }$_id"
    done
    if [[ -n $_dup ]]; then
      printf '✗ layer %s: its parts are left out: %s %s taken (unikit or another layer has a part of that name)\n' \
        "${_layer##*/}" "$_dup" "$([[ $_dup == *,* ]] && echo are || echo is)" >&2
    else
      # shellcheck disable=SC1090
      . "$_layer/components.sh"
    fi
  fi
  _lk=tk; [[ -f $_layer/kit ]] && _lk=$(head -1 "$_layer/kit")
  LAYER_KIT[${_layer##*/}]=$_lk
  for _id in "${COMPONENTS[@]:_n}"; do
    LAYER_OF[$_id]=${_layer##*/}
    _k=$_lk; declare -F "$(fn kit "$_id")" >/dev/null && _k=$("$(fn kit "$_id")")
    [[ -v KIT_LABEL[$_k] ]] || { printf "✗ layer %s: %s names the kit '%s' (tk or fk); using tk\n" "${_layer##*/}" "$_id" "$_k" >&2; _k=tk; }
    KIT_OF[$_id]=$_k
  done
done < <(layer_dirs "$repo")
unset _layer _n _id _lk _k _dup
# kit_of <id>: the kit a part belongs to
kit_of() { echo "${KIT_OF[$1]:-tk}"; }
# A layer's components land at the end of COMPONENTS; bring each group together again, groups
# in the order they first appear and components in their order inside a group.
_regroup() {
  local id g; local -a order=() out=(); local -A grp=()
  for id in "${COMPONENTS[@]}"; do   # each group asked once (a subshell per ask made loading take a second)
    g=$(group_of "$id"); grp[$id]=$g
    [[ " ${order[*]} " == *" ${g// /_} "* ]] || order+=("${g// /_}")
  done
  for g in "${order[@]}"; do
    for id in "${COMPONENTS[@]}"; do [[ ${grp[$id]} == "${g//_/ }" ]] && out+=("$id"); done
  done
  COMPONENTS=("${out[@]}")
}
_regroup; unset -f _regroup
# layer_parts <name>: the components that layer adds, plus claude-skill when it brings skills
layer_parts() {
  local id
  for id in "${COMPONENTS[@]}"; do [[ ${LAYER_OF[$id]:-} == "$1" ]] && echo "$id"; done
  local d; d=$(layer_path "$repo" "$1") && { compgen -G "$d/claude/skills/*/" >/dev/null || [[ -r $d/claude/plugins ]]; } && echo claude-skill
  return 0
}
# kit_parts <kit>: the components that kit sets up, from the toolkit and every layer
kit_parts() {
  local id
  for id in "${COMPONENTS[@]}"; do [[ $(kit_of "$id") == "$1" ]] && echo "$id"; done
  return 0
}
# main_parts: what plain ./install.sh and ./uninstall.sh offer (the tk parts)
main_parts() { kit_parts tk; }
# setup_cmd <id>: how to set it up again: "./install.sh", or its kit's "fk install"
setup_cmd() { local k; k=$(kit_of "$1"); if [[ $k == tk ]]; then echo ./install.sh; else echo "$k install"; fi; }
