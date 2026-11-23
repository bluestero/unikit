#!/usr/bin/env bash
# <kit> configs: the presets the kit's parts bring, in one list that stays open. Enter on one
# shows its choices in the same list; results go in the footer. A part brings a preset with
# config_<id> (docs/LAYERS.md), one line, of one of two kinds:
#
#   file|name|program|the config|the preset|how|your patch's file|what it is
#     A config file. Shown when the program is installed. Choices: the toolkit's preset, the app's
#     own default (no config from the toolkit), what you had before the toolkit, back one step
#     (undo). How it's put in place: link (the file is a link to the preset), block (a marked
#     block in your own file), merge (a file of its own: the preset with your patch laid over it,
#     for a program that rewrites its own config, like btop; the part brings merge_build_<id>
#     (write it), merge_ours_<id> (true: it's what we wrote), merge_made_<id> (prints the file that
#     keeps our checksum) and merge_keep_<id> (prints the program's own changes, for the patch)).
#     A preset is a link into the repo, so editing the config edits the repo's copy: the
#     list calls that "edited preset". Every change first keeps what was there, so undo (one step)
#     brings it back, your edits included; leaving an edited preset puts the repo's copy back as
#     committed, so uk update and git stay clean.
#   dconf|name|extension uuid|dconf path|the preset|name its originals are kept under|what it is|ignore regex
#     A GNOME extension's settings (a dconf dump). Shown when the extension is installed and
#     enabled. Choices: keep, re-apply the preset, reset to the app's defaults, put back what
#     you had before, undo (look_* in components.sh). The ignore regex last: it can hold |.
#
# Your own changes go in a patch: your file in ~/.config/work-toolkit/patches, which the preset
# pulls in last (kitty globinclude, rofi @import, readline $include, dconf loaded after), so it
# wins. A program that can't include a file gets the two merged by its part (bluefeels: starship
# into a file of its own at shell start, btop with the merge kind). The toolkit never writes to a patch once it is made; anyone can copy someone's.
#
# A part can also have config_after_<id> (what has to notice a change; prints a note) and
# config_saved_<id> (after you edit its patch: prints the result line).
set -uo pipefail
SELF="$(readlink -f "${BASH_SOURCE[0]}")"
repo=$(cd "$(dirname "$SELF")/.." && pwd)
mode=ask details=0
# shellcheck source=setup.sh
. "$repo/lib/setup.sh"
# shellcheck source=components.sh
. "$repo/lib/components.sh"
# shellcheck source=inplace.sh
. "$repo/lib/inplace.sh"
snap_dir="$orig_dir/configs"   # <id>.last (what was there before the last change) and <id>.kind
patch_dir="$HOME/.config/work-toolkit/patches"   # the presets name this folder; keep them in step

# __refresh <id> needs no kit (a layer's shell/init.sh, at shell start); everything else is <kit> configs
if [[ ${1:-} != __refresh ]]; then KIT=${1:-tk}; shift; fi

# the kit's presets, one per line: id|kind|the rest of its config_<id> line
cfg_table() {
  local id f
  for id in $(kit_parts "$KIT"); do
    f=$(fn config "$id"); declare -F "$f" >/dev/null && printf '%s|%s\n' "$id" "$("$f")"
  done
  return 0
}
# cfg_row <id>: sets ctype, nice, about and the kind's own: file: app live src kind patch;
# dconf: uuid path src name ign
cfg_row() {
  local line; line=$(grep -m1 "^$1|" <(cfg_table)) || return 1
  IFS='|' read -r id ctype _ <<<"$line"
  if [[ $ctype == dconf ]]; then IFS='|' read -r id ctype nice uuid path src name about ign <<<"$line"
  else
    IFS='|' read -r id ctype nice app live src kind patch about <<<"$line"
    [[ -n $patch ]] && patch="$patch_dir/$patch"
  fi
  return 0
}
# the ones that apply here: the program installed, the extension installed and enabled
cfg_ids() {
  local id ctype a b
  while IFS='|' read -r id ctype _ a _; do
    if [[ $ctype == dconf ]]; then gx_present "$a" && gx_enabled "$a" && echo "$id"
    else type -P "$a" >/dev/null && echo "$id"; fi
  done < <(cfg_table)
}
# your patch has something in it (more than comments)
cfg_patched() { [[ -n $patch && -f $patch ]] && grep -qvE '^[[:space:]]*(#|//|$)' "$patch"; }
# a new patch: what it is, then the preset as comments to start from
cfg_new_patch() {
  local c='#'; [[ $patch == *.rasi ]] && c='//'
  mkdir -p "$patch_dir"
  { printf "%s Your patch for %s: read after the toolkit's preset, so what you set here wins.\n" "$c" "$nice"
    printf '%s The toolkit never changes this file. The preset (%s) is below as comments:\n' "$c" "${src#"$repo"/}"
    printf '%s uncomment a line and change it, or add your own.\n' "$c"
    [[ $patch == *.toml ]] && printf '%s A setting under [a table] needs its [table] line uncommented too.\n' "$c"
    echo
    sed "s|^|$c |" "$src"; } >"$patch"
}

# the preset changed in the repo (no git: never)
cfg_dirty() { git -C "$(dirname "$src")" rev-parse --git-dir >/dev/null 2>&1 && ! git -C "$(dirname "$src")" diff --quiet HEAD -- "$src" 2>/dev/null; }
# the preset as committed, back in the repo
cfg_clean() {
  local top; top=$(git -C "$(dirname "$src")" rev-parse --show-toplevel 2>/dev/null)
  [[ $kind != block ]] && cfg_dirty && git -C "$top" show "HEAD:${src#"$top"/}" >"$src"; return 0
}

# CS: preset (as committed), edited (the preset, changed), own (your file), default (none);
# a dconf preset: preset or own
cfg_state() {
  if [[ $ctype == dconf ]]; then
    if look_applied "$path" "$src" "$ign" "$name"; then CS=preset; else CS=own; fi
  elif [[ $kind == link ]]; then
    if linked "$live" "$src"; then if cfg_dirty; then CS=edited; else CS=preset; fi
    elif [[ -e $live || -L $live ]]; then CS=own
    else CS=default; fi
  elif [[ $kind == merge ]]; then   # its own file; a link is from older installs
    if linked "$live" "$src"; then if cfg_dirty; then CS=edited; else CS=preset; fi
    elif "$(fn merge_ours "$id")"; then CS=preset
    elif [[ -f $live && -f $("$(fn merge_made "$id")") ]]; then CS=edited   # changed by the program since the toolkit wrote it
    elif [[ -e $live ]]; then CS=own
    else CS=default; fi
  else
    if has_block "$live" "$(<"$src")"; then CS=preset
    elif grep -qxF "$BLOCK_START" "$live" 2>/dev/null; then CS=edited
    else CS=default; fi
  fi
}
cfg_word() {
  if [[ $ctype == dconf ]]; then
    if [[ $1 == preset ]]; then printf '%s' "${C_GREEN}✓${C_RESET} toolkit preset"; [[ -f $(look_patch "$name") ]] && printf ' + my patch'
    else printf '%s' "your own settings"; fi
    return 0
  fi
  case $1 in
    preset)  printf '%s' "${C_GREEN}✓${C_RESET} toolkit preset" ;;
    edited)  printf '%s' "${C_YELLOW}edited preset${C_RESET}" ;;
    own)     printf '%s' "your own file" ;;
    default) printf '%s' "app's default" ;;
  esac
  [[ $1 == preset || $1 == edited ]] && cfg_patched && printf ' + my patch'
  return 0
}

# keep what is there now, for undo: link (the preset's text, edits and all), file, or none
cfg_snap() {
  mkdir -p "$snap_dir"
  if [[ $kind == link ]] && linked "$live" "$src"; then cp "$src" "$snap_dir/$id.last"; echo link >"$snap_dir/$id.kind"
  elif [[ -f $live ]]; then cp "$live" "$snap_dir/$id.last"; echo file >"$snap_dir/$id.kind"
  else rm -f "$snap_dir/$id.last"; echo none >"$snap_dir/$id.kind"; fi
}
# your file from before the toolkit (empty when there was none)
cfg_before() { local o; o=$(original_of "$live"); [[ -n $o && -f $o ]] && printf '%s' "$o"; }

CH_PRE="Toolkit preset"; CH_APP="App's default"; CH_OLD="What you had before"; CH_UND="Undo the last change"
CH_EDT="Edit my patch"; CH_DRP="Drop my patch"; CH_KPT="Keep these changes as my patch"
# What a dconf choice does (look_choices gives the choices)
cfg_look_note() {
  case $1 in
    "$LOOK_KEEP") echo "nothing changes" ;;
    "$LOOK_APP")  echo "the toolkit's preset for these settings" ;;
    "$LOOK_RST")  echo "asks first; undo brings them back" ;;
    "$LOOK_PRE")  echo "what you had before the toolkit set them" ;;
    "$LOOK_UND")  echo "one step back" ;;
    "$LOOK_KPT")  echo "what you changed goes in your patch (~/.config/work-toolkit/patches), loaded after the preset" ;;
    "$LOOK_DRP")  echo "back to the plain preset (your patch is kept as <name>.dropped)" ;;
  esac
}
cfg_choices() {   # what a preset can switch to now: choice<TAB>what it does
  cfg_state
  if [[ $ctype == dconf ]]; then
    local c differs=""; [[ $CS == own ]] && differs=1
    look_choices "$name" "$differs" | while IFS= read -r c; do printf '%s\t%s\n' "$c" "$(cfg_look_note "$c")"; done
    return 0
  fi
  case $CS in
    preset) ;;
    edited) printf '%s\t%s\n' "$CH_PRE" "the toolkit's ${src#"$repo"/} as committed (your edits kept for undo)" ;;
    *)      printf '%s\t%s\n' "$CH_PRE" "the toolkit's ${src#"$repo"/}" ;;
  esac
  if [[ $CS != default ]]; then
    if [[ $kind == link ]]; then printf '%s\t%s\n' "$CH_APP" "no config file: $nice's built-in settings"
    else printf '%s\t%s\n' "$CH_APP" "the toolkit's keys taken out; the rest of ${live/#$HOME/\~} stays"; fi
  fi
  [[ -n $(cfg_before) ]] && printf '%s\t%s\n' "$CH_OLD" "your ${live/#$HOME/\~} from before the toolkit"
  [[ -f $snap_dir/$id.kind ]] && printf '%s\t%s\n' "$CH_UND" "one step back"
  [[ $kind == merge && $CS == edited ]] &&
    printf '%s\t%s\n' "$CH_KPT" "the settings that differ from the preset go in ${patch/#$HOME/\~}, so they stay"
  if [[ -n $patch && ( $CS == preset || $CS == edited ) ]]; then
    if [[ -f $patch ]]; then printf '%s\t%s\n' "$CH_EDT" "your changes on top of the preset, in ${patch/#$HOME/\~}"
    else printf '%s\t%s\n' "$CH_EDT" "start one from the preset: your changes go in ${patch/#$HOME/\~}, the toolkit's file stays as it is"; fi
  fi
  [[ -n $patch && -f $patch ]] && printf '%s\t%s\n' "$CH_DRP" "back to the plain preset (your patch kept as ${patch##*/}.dropped)"
  return 0
}

# cfg_do <choice>: prints the result line (✓ … or ✗ …)
cfg_do() {
  local pick=$1
  if [[ $ctype == dconf ]]; then look_do "$path" "$src" "$name" "$nice" "$pick" "$ign"; return; fi
  setup_phase=install keep_original "$live"   # your own file, kept once (what you had before)
  case $pick in
    "$CH_PRE") cfg_snap; cfg_clean
      case $kind in
        link)  mkdir -p "${live%/*}"; rm -f "$live"; ln -s "$src" "$live" ;;
        merge) "$(fn merge_build "$id")" ;;
        block) mkdir -p "${live%/*}"; set_block "$live" "$(<"$src")" ;;
      esac
      echo "✓ $nice: toolkit preset" ;;
    "$CH_APP") cfg_snap; cfg_clean
      if [[ $kind == block ]]; then drop_block "$live"; else rm -f "$live"; fi
      echo "✓ $nice: the app's default" ;;
    "$CH_OLD") local o; o=$(cfg_before); cfg_snap; cfg_clean
      rm -f "$live"; mkdir -p "${live%/*}"; cp -p "$o" "$live"
      echo "✓ $nice: what you had before the toolkit" ;;
    "$CH_UND") cfg_undo ;;
    "$CH_DRP") cfg_snap; mv "$patch" "$patch.dropped"; [[ $kind == merge ]] && "$(fn merge_build "$id")"
      echo "✓ $nice: patch dropped (kept as ${patch/#$HOME/\~}.dropped)" ;;
    "$CH_KPT") cfg_keep; echo "✓ $nice: its changes are your patch now (${patch/#$HOME/\~})" ;;
    *) echo "✗ nothing changed"; return 0 ;;
  esac
  local f; f=$(fn config_after "$id"); declare -F "$f" >/dev/null && "$f"
  return 0
}
# undo: what was there before the last change comes back; undo again redoes it
cfg_undo() {
  local k t; k=$(<"$snap_dir/$id.kind"); t=$(mktemp)
  [[ $k == none ]] || cp "$snap_dir/$id.last" "$t"
  cfg_snap
  case $k in
    link) rm -f "$live"; mkdir -p "${live%/*}"; cat "$t" >"$src"; ln -s "$src" "$live" ;;
    file) rm -f "$live"; mkdir -p "${live%/*}"; cat "$t" >"$live" ;;
    none) rm -f "$live" ;;
  esac
  rm -f "$t"
  echo "✓ $nice: back to before the last change"
}
# a merge preset's settings the program changed (merge_keep_<id>), added to the patch; then its file again
cfg_keep() {
  local t; cfg_snap; cfg_clean; t=$(mktemp)
  [[ -f $patch ]] || cfg_new_patch
  "$(fn merge_keep "$id")" >"$t"
  [[ -s $t ]] && { printf '\n# kept from %s (%s)\n' "$app" "$(date +%F)"; cat "$t"; } >>"$patch"
  rm -f "$t"; "$(fn merge_build "$id")"
}

# ------------------------------------------------------------------ list ---
cfg_rows() {   # a title row, then name · config · what it is, the id after a TAB
  local i S=$'\x1f' id ctype nice app live src kind patch about uuid path name ign
  printf 'APP%sCONFIG%sWHAT IT IS\n' "$S" "$S"
  for i in $(cfg_ids); do cfg_row "$i"; cfg_state; printf '%s\t%s\n' "$nice$S$(cfg_word "$CS")$S$about" "$id"; done
}
cfg_menu_rows() {   # a title row, then choice · what it does, the choice after a TAB
  local c n S=$'\x1f'
  printf 'CHOICE%sWHAT IT DOES\n' "$S"
  cfg_choices | while IFS=$'\t' read -r c n; do printf '%s\t%s\n' "$c$S$n" "$c"; done
}
cfg_lay() { print_table 3 "$(ui_pick_width)" <"$IP/cells.$1" >"$IP/rows.$1"; }
CFG_KEYS="# Pick one, then which config it uses
enter: choose · esc: close"

cfg_list() {
  [[ -n $(cfg_table) ]] || { info "Nothing here yet: $KIT's parts bring no presets. Add a layer: uk layers"; return 0; }
  [[ -n $(cfg_ids) ]] || die "none of the apps with a preset here is installed · see: $KIT install"
  ui_fzf_at_least 0.63 || die "the list needs fzf 0.63 or newer · tk install fzf"
  IP=$(mktemp -d) || return 1; export IP
  trap 'rm -rf "$IP"' EXIT
  ip_set mode list
  cfg_rows >"$IP/cells.list"; cfg_lay list
  local cb k; cb="bash $(printf %q "$SELF") $KIT __key"
  local -a binds=(--bind "start:unbind(y,n)")
  for k in enter esc y n resize; do binds+=(--bind "$k:transform:$cb $k {2} {q}"); done
  ui_fzf "$KIT · configs" --toast --with-shell='bash -c' --delimiter='\t' --with-nth=1 --header-lines=1 \
    --prompt='app> ' --footer=' ' --header="$CFG_KEYS" "${binds[@]}" <"$IP/rows.list" >/dev/null
  return 0   # esc is the way out (fzf's 130), not an error
}

cfg_relist() { cfg_rows >"$IP/cells.list"; cfg_lay list; cat "$IP/rows.list"; }
cfg_to_list() {   # [toast]: back to the list, the cursor on the one just changed
  # the rows are made as fzf reloads: after the editor (Edit my patch) they have changed
  local n; n=$(awk -F'\t' -v id="$(ip_get cur)" '$2 == id { print NR - 1; exit }' "$IP/rows.list")
  local -a a=("$(ip_back)" "$(ip_fz reload-sync "bash $(printf %q "$SELF") $KIT __relist")" "pos(${n:-1})"
    "$(ip_fz change-header "$(ui_keys "$CFG_KEYS")")" "$(ip_fz change-prompt 'app> ')")
  if [[ -n ${1:-} ]]; then a+=("$(ui_toast "$1")"); else a+=("$(ip_fz change-footer " ")"); fi
  ip_join "${a[@]}"
}
cfg_run() {   # choice → back to the list with the result in the footer
  local out; out=$(cfg_do "$1" 2>&1); out=$(strip_ansi "$out" | grep -v '^$' | tr '\n' ' ' | sed 's/^[[:space:]]*//; s/[[:space:]]*$//')
  [[ $out == ✓* ]] || out="✗ ${out:-nothing changed}"
  cfg_to_list "$out"
}

cfg_key() {   # key value query (value: the id in the list, the choice in the menu)
  local k=$1 v=$2 q=$3 m id ctype nice app live src kind patch about uuid path name ign
  m=$(ip_get mode)
  if [[ $k == resize ]]; then
    local w=list; [[ $m == list ]] || w=menu
    cfg_lay "$w"; ip_join "$(ip_fz reload-sync "cat $(printf %q "$IP/rows.$w")")" "pos(${FZF_POS:-1})"; return
  fi
  case $m in
    list)
      case $k in
        esc) echo abort ;;
        enter)
          [[ -n $v ]] && cfg_row "$v" || return 0
          ip_set saved_q "$q"; ip_set mode menu; ip_set cur "$id"
          cfg_menu_rows >"$IP/cells.menu"; cfg_lay menu
          cfg_state
          ip_join "$(ip_fz reload-sync "cat $(printf %q "$IP/rows.menu")")" first "$(ip_fz change-query "")" disable-search \
            "$(ip_fz change-header "$(ui_keys "# $nice ($about) now uses: $(strip_ansi "$(cfg_word "$CS")")"$'\n'"enter: switch to it · esc: back")")" \
            "$(ip_fz change-prompt "$nice> ")" "$(ip_fz change-footer " ")" ;;
      esac ;;
    menu)
      cfg_row "$(ip_get cur)"
      case $k in
        esc) cfg_to_list ;;
        enter)
          [[ -n $v ]] || return 0
          if [[ $ctype == dconf ]]; then
            if [[ $v == "$LOOK_RST" ]]; then
              ip_set pick "$v"; ip_confirm "Reset $nice to the app's defaults? (the menu can undo it)" reset n; return
            fi
            cfg_run "$v"; return
          fi
          if [[ $v == "$CH_EDT" ]]; then   # the editor full screen, then back to the list
            [[ -f $patch ]] || cfg_new_patch
            [[ $kind == merge ]] && cfg_snap   # its file is made again afterwards: undo brings this one back
            ip_join "$(ip_fz execute "${VISUAL:-${EDITOR:-nano}} $(printf %q "$patch")")" \
              "$(ip_fz transform "bash $(printf %q "$SELF") $KIT __edited $id")"; return
          fi
          if [[ $v == "$CH_DRP" ]]; then
            ip_set pick "$v"; ip_confirm "Drop your $nice patch? It's kept as ${patch##*/}.dropped." drop n; return
          fi
          cfg_state
          # your own file or your edits would be replaced: ask first (undo still brings them back)
          if [[ $v != "$CH_UND" && ( $CS == own || $CS == edited ) ]]; then
            local what="your own ${live/#$HOME/\~}"
            if [[ $CS == edited && $kind == merge && ! -L $live ]]; then what="the changes made in $nice's menu"
            elif [[ $CS == edited ]]; then what="the uncommitted changes in the repo's ${src#"$repo"/} (yours, or work in progress there)"; fi
            ip_set pick "$v"; ip_confirm "Switch $nice to: $v? This replaces $what (undo brings it back)." switch n; return
          fi
          cfg_run "$v" ;;
      esac ;;
    confirm)
      local a; a=$(ip_answer "$k"); [[ -n $a ]] || return 0
      cfg_row "$(ip_get cur)"
      if [[ $a == yes ]]; then cfg_run "$(ip_get pick)"; else cfg_to_list "Nothing changed"; fi ;;
  esac
}

case "${1:-}" in
  "")    cfg_list ;;
  __key) [[ -z ${NO_COLOR:-} ]] && ui_color; cfg_key "${2:-}" "${3:-}" "${4:-}" ;;
  __relist) [[ -z ${NO_COLOR:-} ]] && ui_color; cfg_relist ;;
  __edited)   # after the editor: what the patch feeds, then back to the list with how it went
    [[ -z ${NO_COLOR:-} ]] && ui_color; cfg_row "${2:-}" || exit 0
    f=$(fn config_saved "$id")
    if declare -F "$f" >/dev/null; then cfg_to_list "$("$f")"; else cfg_to_list "✓ $nice: your patch saved"; fi ;;
  __refresh)  # __refresh <id>, at shell start after the preset or the patch changed: a merge preset's
    # file again, unless the program changed it since the toolkit wrote it
    KIT=$(kit_of "${2:-}"); cfg_row "${2:-}" 2>/dev/null || exit 0
    made=$("$(fn merge_made "$id")")
    [[ -f $made && -f $live && ! -L $live ]] &&
      [[ $(sha256sum "$live" | cut -d' ' -f1) == "$(<"$made")" ]] && "$(fn merge_build "$id")" ;;
  *)     ui_unknown "$KIT configs" "$1" ;;
esac
