#!/usr/bin/env bash
# Removes parts of unikit and its layers. Opens the installer's tabs, a tab per group,
# to tick what's installed with tab; enter removes it. Safe to run any number of times.
# `./uninstall.sh help` lists the commands. Files that were replaced get their
# backup put back. Repo files are never deleted.
set -uo pipefail

repo="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")" && pwd)"
mode=ask details=0 list=0 help=0 layer="" kit=""
wanted=()
for arg in "$@"; do
  case "$arg" in
    ls|list)        list=1 ;;
    help|-h|--help) help=1 ;;
    -n|--dry-run)   mode=dry ;;
    -y|--yes)       mode=yes ;;
    -p|--plain)     export UNIKIT_PLAIN=1 ;;
    --layer=*)      layer=${arg#--layer=} ;;
    --kit=*)        kit=${arg#--kit=} ;;
    -*) printf '✗ unknown option %s · see: ./uninstall.sh help\n' "$arg" >&2; exit 2 ;;
    *)  wanted+=("$arg") ;;
  esac
done

. "$repo/lib/setup.sh"
. "$repo/lib/components.sh"
. "$repo/lib/tabs.sh"

if (( help )); then
  ui_help ./uninstall.sh "remove parts of unikit and its layers" <<'EOF'
## Commands
./uninstall.sh	a tab per group: tick what's installed, enter removes it
./uninstall.sh <component>...	just those, e.g. ./uninstall.sh zsh
./uninstall.sh ls	what's installed, so could be removed
./uninstall.sh help	this page

## Options
--dry-run	show what would be removed; changes nothing
--yes	no questions (components must be named)
--plain	don't use gum even if it's installed
--layer=<name>	only that layer's parts
--kit=<tk|fk>	only that kit's parts, from the toolkit and every layer (fk uninstall uses it)

You get your own setup back: replaced files, the lines taken out of ~/.bashrc,
your default terminal, Ctrl+Alt+T and login shell. Repo files are never deleted.
What you had before: ~/.local/state/unikit/originals
EOF
  exit 0
fi
use_gum

# What this run may touch: one layer's parts (--layer), one kit's (--kit), else the tk parts
if [[ -n $layer ]]; then
  layer_path "$repo" "$layer" >/dev/null || { printf '✗ no layer %s · see: uk layers\n' "'$layer'" >&2; exit 2; }
  mapfile -t allowed < <(layer_parts "$layer")
elif [[ -n $kit ]]; then
  [[ -v KIT_LABEL[$kit] ]] || { printf '✗ no kit %s (tk or fk)\n' "'$kit'" >&2; exit 2; }
  mapfile -t allowed < <(kit_parts "$kit")
  (( ${#allowed[@]} )) || { echo "$kit has no parts yet: no layer brings any. Add one: uk layers"; exit 0; }
else mapfile -t allowed < <(main_parts); fi
again=./install.sh
if [[ -n $layer ]]; then _k=${LAYER_KIT[$layer]:-tk}; else _k=${kit:-tk}; fi
[[ $_k != tk ]] && again="$_k install"
for w in "${wanted[@]}"; do
  [[ " ${allowed[*]} " == *" $w "* ]] && continue
  if [[ " ${COMPONENTS[*]} " == *" $w "* ]]; then printf '✗ %s is removed with: %s %s\n' "'$w'" "$(setup_cmd "$w" | sed 's/ install$/ uninstall/; s/install.sh$/uninstall.sh/')" "$w" >&2
  else printf '✗ unknown command or component %s · see: ./install.sh ls\n' "'$w'" >&2; fi
  exit 2
done

# Only what's actually there can be removed.
present=() labels=()
states_all "${allowed[@]}"
for id in "${allowed[@]}"; do
  STATE=${ST[$id]}
  [[ "$STATE" == installed || "$STATE" == partial ]] || continue
  present+=("$id")
  labels+=("$id"$'\t'"$("$(fn title "$id")")")
done

say ""
if (( ${#present[@]} == 0 )); then
  say "Nothing ${layer:+of $layer }is installed. Nothing to do."
  exit 0
fi

chosen=()
if (( ${#wanted[@]} )); then
  for w in "${wanted[@]}"; do
    if [[ " ${present[*]} " == *" $w "* ]]; then chosen+=("$w"); else say "  ${D}$w: not installed, skipping${R}"; fi
  done
elif dry || (( list )); then
  { printf '%s\n' "${B}COMPONENT${R}"$'\x1f'"${B}WHAT IT IS${R}"
    for l in "${labels[@]}"; do printf '%s\n' "${l%%$'\t'*}"$'\x1f'"$D${l#*$'\t'}$R"; done
  } | ui_table "unikit · installed" "${#present[@]} could be removed"
  exit 0
elif [[ "$mode" == yes ]]; then
  echo "--yes needs the components named, e.g.: ./uninstall.sh --yes zsh"; exit 2
else
  [[ -t 0 ]] || { echo "Run it in a terminal to pick from the list, or name the components: ./uninstall.sh zsh"; exit 1; }
  if [[ -t 1 ]] && ui_fzf_at_least 0.63; then   # the installer's tabs, a tab per group (lib/tabs.sh)
    wanted=("${allowed[@]}") todo=("${present[@]}") preticked=() undo=${again/install/uninstall} tabs_remove=1
    tabs_pick || { say "Cancelled. Nothing changed."; exit 0; }
    chosen=("${todo[@]}")
  else
    checklist "Select what to remove:" "${labels[@]}" || { say "Cancelled. Nothing changed."; exit 0; }
    for i in "${CHECKLIST[@]}"; do chosen+=("${present[i]}"); done
  fi
fi
(( ${#chosen[@]} )) || { say "Nothing selected. Nothing changed."; exit 0; }

if dry; then
  say "Would remove: ${chosen[*]}"
  exit 0
fi
say ""
say "Removing: ${B}${chosen[*]}${R}"
ask "Go ahead?" || { say "Nothing changed."; exit 0; }

run_lock "uninstall ${chosen[*]}"
logf ""; logf "=== uninstall $ts ${chosen[*]}"
# login-shell before zsh, so the login shell is never left pointing at a removed zsh
order=()
[[ " ${chosen[*]} " == *" login-shell "* ]] && order+=(login-shell)
for id in "${chosen[@]}"; do [[ "$id" == login-shell ]] || order+=("$id"); done
run_start "${again/install/uninstall}" "${order[@]}"   # cut short: says what's done and what isn't
for id in "${order[@]}"; do
  run_part "$id"
  say "${B}$id${R}"
  "$(fn uninstall "$id")"
done
run_finished

say ""
summary=""
for id in "${order[@]}"; do
  "$(fn state "$id")"
  if [[ "$STATE" == installed || "$STATE" == partial ]]; then summary+="${Y}◐${R} $("$(fn label "$id")")"$'\x1f'"${D}still partly there · see the log${R}"$'\n'
  else summary+="${G}✓${R} $("$(fn label "$id")")"$'\x1f'"${D}removed · $again $id puts it back${R}"$'\n'; fi
done
printf '%s' "$summary" | print_table 3 | sed 's/\x1b\[[0-9;]*m//g' >>"$log_file"
if [[ -t 1 ]]; then
  printf '%s' "$summary" | print_table 3 | ui_box "done" "open a new terminal to see the change" 0 "$(ui_hint "log: ${log_file/#$HOME/\~}")"
else
  printf '%s' "$summary" | print_table 3
fi
