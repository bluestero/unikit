# Layers: extra parts kept in their own repos and cloned into layers/<name>/
# (tk layer add <git-url>; layers/ is gitignored). The toolkit finds them; there
# is nothing to register. A layer can have any of these, all optional:
#
#   bin/              its commands, put on PATH; bin/fk-<name> is also fk <name> (fk's own
#                     words, install, uninstall and help, stay fk's)
#   shell/init.sh     sourced by every shell (bash and zsh) before the tools load:
#                     settings the tools read (OKTA_AWSCLI_*, KX_ALIAS_RULES, ...), aliases
#   components.sh     installer components: COMPONENTS+=(id ...), the usual
#                     label_/title_/detail_/state_/install_/uninstall_ functions,
#                     group_<id> to name its group (its installer tab), and
#                     GROUP_ABOUT[<group>]="one line" for a group of its own
#                     CLASHES+=("id id|question") for two parts that shouldn't both be in
#   kit               one line: the kit its parts go to unless a part says otherwise (default tk);
#                     a part names its own with kit_<id>() { echo fk; }. tk install sets up
#                     the tk parts, fk install the fk parts, from every layer
#   tools             its commands for the kit's picker and help:
#                       name|group|what it does|program it needs[|kit]
#                     (kit: tk or fk; without it, the layer's kit)
#   workspaces        a shared ws list; "@<name>" in your own list brings it in
#   claude/skills/*/  Claude Code skills, linked by the claude-skill component
#
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
  for f in "$1"/layers/*/bin/"$2"; do [[ -x $f ]] && { printf '%s
' "$f"; return 0; }; done
  return 1
}
