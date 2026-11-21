# Layers: extra parts kept in their own repos and cloned into layers/<name>/
# (docs/LAYERS.md is the whole contract; docs/layer-template/ a layer to start from)
# (uk layer add <git-url>; layers/ is gitignored). The toolkit finds them; there
# is nothing to register. A layer can have any of these, all optional:
#
#   bin/              its commands, put on PATH after unikit's (a command unikit has stays
#                     unikit's); bin/fk-<name> is also fk <name> (fk's own words, install,
#                     uninstall and help, stay fk's)
#   shell/init.sh     sourced by every shell (bash and zsh) before the tools load:
#                     settings the tools read (OKTA_AWSCLI_*, KX_ALIAS_RULES, ...), aliases
#   components.sh     installer components: COMPONENTS+=(id ...), names no one else has (a layer
#                     with a taken name has its parts left out), the usual
#                     label_/title_/detail_/state_/install_/uninstall_ functions,
#                     touches_<id> for what it changes (a file, or dconf:/a/path/: the installer
#                     asks before changing what another layer's part set up; addboth_<id> if it
#                     can sit beside that one),
#                     group_<id> to name its group (its installer tab), and
#                     GROUP_ABOUT[<group>]="one line" for a group of its own
#                     CLASHES+=("id id|question") for two parts that shouldn't both be in
#   kit               one line: the kit its parts go to unless a part says otherwise (default tk);
#                     a part names its own with kit_<id>() { echo fk; }. tk install sets up
#                     the tk parts, fk install the fk parts, from every layer
#   tools             its commands for the kit's picker and help:
#                       name|group|what it does|program it needs[|kit]
#                     (kit: tk or fk; without it, the layer's kit)
#   requires          the layers it needs, one name per line (uk doctor and uk layer add say
#                     when one isn't there). A layer needs only unikit and itself, unless it says so here
#   workspaces        a shared ws list; "@<name>" in your own list brings it in
#   claude/skills/*/  Claude Code skills, linked by the claude-skill component
#
# Trust: a layer's code runs on your machine (every shell, its commands, the installer).
# uk layer add shows what it brings and asks first (default No); layers.lock (in the root,
# not in git) pins the commit you said yes to, and uk update shows the files that run code
# changed since that pin before it pulls them (--yes holds those layers back).
# The kits: tk (what you work with) and fk (how it looks). Each one's command sets up its own
# parts: tk install, fk install. Both are always there.
declare -gA KIT_LABEL=([tk]=toolkit [fk]=feelkit)

# layer_dirs <toolkit root>: one layer folder per line, sorted by name
layer_dirs() {
  local d
  for d in "$1"/layers/*/; do [[ -d $d ]] && printf '%s\n' "${d%/}"; done
  return 0
}
# layer_path <toolkit root> <name>: that layer's folder; 1 when there is none
layer_path() { [[ -d $1/layers/$2 ]] && printf '%s\n' "$1/layers/$2"; }
# layer_tools <toolkit root> <kit>: the layers' tools lines for that kit
layer_tools() {
  local d t lk k
  while IFS= read -r d; do
    [[ -r $d/tools ]] || continue
    lk=tk; [[ -f $d/kit ]] && lk=$(head -1 "$d/kit")
    while IFS= read -r t; do
      [[ -z $t || $t == \#* ]] && continue
      IFS='|' read -r _ _ _ _ k <<<"$t"
      [[ ${k:-$lk} == "$2" ]] && printf '%s\n' "$t"
    done <"$d/tools"
  done < <(layer_dirs "$1")
  return 0
}
# layer_bin <toolkit root> <command>: the first layer's bin/<command>; 1 when no layer has it
layer_bin() {
  local f
  for f in "$1"/layers/*/bin/"$2"; do [[ -x $f ]] && { printf '%s\n' "$f"; return 0; }; done
  return 1
}
# own_repo <dir>: a git clone of its own (a layer copied in by hand is part of nothing,
# and git would otherwise answer for the toolkit repo around it)
own_repo() { [[ "$(git -C "$1" rev-parse --show-toplevel 2>/dev/null)" == "$(cd "$1" && pwd -P)" ]]; }
# layer_kit <dir>: the kit its parts go to unless a part says otherwise
layer_kit() { local k=tk; [[ -f $1/kit ]] && k=$(head -1 "$1/kit"); printf '%s\n' "$k"; }
# layer_requires <dir>: the layers it needs (its requires file), one per line
layer_requires() { [[ -r $1/requires ]] && grep -v '^[[:space:]]*\(#\|$\)' "$1/requires"; return 0; }
# layer_missing <dir>: the ones of those that aren't here
layer_missing() { local t; while IFS= read -r t; do [[ -d ${1%/layers/*}/layers/$t ]] || echo "$t"; done < <(layer_requires "$1"); }
# layers.lock: "name TAB commit" per layer, the commit you last looked at and trusted
pin_of() { [[ -r $1/layers.lock ]] && awk -F'\t' -v n="$2" '$1 == n { print $2 }' "$1/layers.lock"; return 0; }   # root name
pin_set() {   # root name [commit]: without a commit the pin goes
  local f=$1/layers.lock t; t=$(mktemp)
  { [[ -r $f ]] && awk -F'\t' -v n="$2" '$1 != n' "$f"; [[ -n ${3:-} ]] && printf '%s\t%s\n' "$2" "$3"; } >"$t"
  mv "$t" "$f"
}
# layer_code <dir> <from> <to>: the files changed between two commits that run code: all but
# the docs and the plain lists (tools, kit, requires, workspaces, VERSION)
layer_code() {
  git -C "$1" diff --name-only "$2" "$3" -- 2>/dev/null |
    grep -Ev '^(tools|kit|requires|workspaces|VERSION|\.gitignore|LICENSE[^/]*|[^/]*\.md|docs/.*)$'
  return 0
}
