#!/usr/bin/env bash
# Gets the toolkit onto a machine:
#
#   bash <(curl -fsSL https://raw.githubusercontent.com/bluestero/unikit/main/bootstrap.sh)
#
# Clones it into ~/.local/share/unikit (or pulls, if it's already there) and
# puts the tk command in ~/.local/bin. Nothing else changes: `tk install` then
# shows the checklist. --dir <folder> puts the toolkit somewhere else.
#
# --layer <name or git URL> also adds a layer (repeat it for more): bluetools (the work
# tools: okcli, kx, twin, ws, hat, ctx) and bluefeels (a look: kitty, the shell, GNOME) by
# name, any other layer by its git URL. Example:
#   bash <(curl -fsSL .../bootstrap.sh) --layer bluetools --layer bluefeels
set -euo pipefail

url="${TK_REPO:-https://github.com/bluestero/unikit.git}"
dir="${TK_DIR:-$HOME/.local/share/unikit}"
layers=()
while (( $# )); do
  case "$1" in
    --dir)     dir="${2:?--dir needs a folder}"; shift 2 ;;
    --layer)   layers+=("${2:?--layer needs a name or a git URL}"); shift 2 ;;
    --layer=*) layers+=("${1#--layer=}"); shift ;;
    *)         echo "✗ unknown option: $1 (--dir <folder>, --layer <name or git URL>)" >&2; exit 1 ;;
  esac
done
dir=$(realpath -m -- "$dir")

command -v git >/dev/null || { echo "✗ git isn't installed (Ubuntu: sudo apt install git)" >&2; exit 1; }
# its folder before unikit was its name: moved, once (tk install then fixes what pointed there)
old="$HOME/.local/share/unix-toolkit"; moved=""
if [[ -z ${TK_DIR:-} && $dir == "$HOME/.local/share/unikit" && -d $old/.git && ! -e $dir ]]; then
  mv "$old" "$dir" && moved="   (the shell line and the commands still point at the old folder: set them up again)" && echo "✓ moved ${old/#$HOME/\~} to ${dir/#$HOME/\~} (its new name)"
fi
if [[ -d $dir/.git ]]; then
  git -C "$dir" pull --ff-only -q && echo "✓ toolkit updated in ${dir/#$HOME/\~}"
else
  mkdir -p "$(dirname "$dir")"
  git clone -q "$url" "$dir" && echo "✓ toolkit cloned into ${dir/#$HOME/\~}"
fi

mkdir -p "$HOME/.local/bin"
ln -sfn "$dir/bin/tk" "$HOME/.local/bin/tk" && echo "✓ tk command in ~/.local/bin"

# layers: bluetools and bluefeels by name (lib/layers.sh), anything else by its git URL.
# `uk layer add` shows what runs, asks, and offers to set up its parts.
for l in "${layers[@]}"; do
  n=${l%.git}; n=${n##*/}; n=${n#unix-}; n=${n%-toolkit}; [[ $n == bluefeel || $n == feelkit ]] && n=bluefeels
  if [[ -d $dir/layers/$n ]]; then echo "✓ layer $n already there"
  else echo; "$dir/bin/uk" layer add "$l" || echo "✗ couldn't add the layer $l (see above)" >&2; fi
done

echo
case ":$PATH:" in
  *":$HOME/.local/bin:"*) echo "Next: tk install$moved" ;;
  *) echo "Next: ~/.local/bin/tk install   (plain \`tk\` works once you open a new terminal after installing)" ;;
esac
