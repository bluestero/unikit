# The example layer's installer parts. unikit's lib/components.sh sources this after its own,
# so its helpers are here: ask, ok, skip, warn, fail, dry, linked, link_file, unlink_file,
# set_block, has_block, drop_block, apt_install (docs/LAYERS.md lists them).
# Every name here starts with the layer's name: unikit and other layers have parts too.
example_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

COMPONENTS+=(example-hello)
group_example_hello() { echo Example; }
GROUP_ABOUT[Example]="The example layer's parts: rename them to your own."

# -------------------------------------------------------- example-hello ---
# Links the example-hello command into ~/.local/bin, so it runs outside unikit's shells too.
label_example_hello()  { echo "example-hello"; }
title_example_hello()  { echo "the example-hello command in ~/.local/bin"; }
detail_example_hello() { echo "~/.local/bin/example-hello -> $example_root/bin/example-hello"; }
touches_example_hello() { echo "$HOME/.local/bin/example-hello"; }   # what it changes: asked about if another layer has it
state_example_hello() {
  NOTE=""
  if linked "$HOME/.local/bin/example-hello" "$example_root/bin/example-hello"; then STATE=installed; else STATE=missing; fi
}
install_example_hello() {
  linked "$HOME/.local/bin/example-hello" "$example_root/bin/example-hello" && return
  ask "Link example-hello into ~/.local/bin?" || { skip; return; }
  link_file "$HOME/.local/bin/example-hello" "$example_root/bin/example-hello"
}
uninstall_example_hello() { unlink_file "$HOME/.local/bin/example-hello" "$example_root/bin/example-hello"; }
