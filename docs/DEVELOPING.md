# Working on unikit

For changing unikit itself. To add tools without changing it, write a layer instead:
[LAYERS.md](LAYERS.md).

The look and the rules every command follows (pickers, questions inside lists, colours, keys to
leave alone) are in [CLAUDE.md](../CLAUDE.md). They apply to the layers' commands too.

## Layout

```
bin/uk, bin/tk, bin/fk      the base and its two kits (lib/kit.sh: their shared words and pages)
lib/ui.sh                   shared look + command rules for every command (box, help, colours, fzf)
lib/inplace.sh              questions inside a list that stays open
lib/setup.sh, components.sh install/uninstall plumbing, unikit's parts and the helpers layers use
lib/layers.sh               what a layer can hold; layers/ (gitignored) holds them
lib/configs.sh              <kit> configs: the presets the kit's parts bring
lib/workspaces.sh           the workspace list (yours plus the layers' shared ones)
lib/platform.sh             OS, distro, package manager, GNOME? (requires_of says what each part needs)
shell/init.sh               the one file bash and zsh load (the layers, then tk's hook and completion)
install.sh / uninstall.sh   set up / remove, per part
bootstrap.sh                the one-command download (clone or pull, add the tk command, add layers)
docs/                       INSTALL.md, COMMANDS.md, LAYERS.md (writing a layer), layer-template/
tests/                      kept tests (see below)
```

## Tests

`tests/run.sh` drives the pickers in a pseudo-terminal, with a scratch HOME and fake system
commands, so it never touches your settings, cloud or cluster (needs `uv`).

```bash
tests/run.sh             # everything: unikit's tests/cases/ and each layer's layers/<name>/tests/cases/
tests/run.sh uk          # one file
tests/run.sh speed       # times keys and start-up against the budgets in tests/lib/budget.py
```

A layer's speed tests are `speed_<name>`.

## Shipping a change

- **Bump `VERSION`** when you push something people will notice: 1.2.0 → 1.3.0 for new things,
  → 1.2.1 for fixes.
- **Rename, move or drop a part's files freely.** The installer records every link it makes
  (`~/.local/state/unikit/links`), so `uk update` finds the ones left pointing nowhere. What isn't a
  link (dconf, apt, dotfile blocks) a dropped part can't clean up after the pull, so drop those by hand.
- **Keep code and doc changes in separate commits** in a layer: `uk update` shows people the changed
  code before they trust it, and docs don't count ([LAYERS.md](LAYERS.md#trust-what-people-see-before-your-code-runs)).
