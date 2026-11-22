# Writing a layer

A layer adds to unikit without changing it: a team's settings, repos and commands, or one
person's own look, kept in a repo of its own. unikit clones it into `layers/<name>/` and finds
everything in it by its place. Nothing is registered, and unikit never changes for it.

This page is for whoever writes one, a person or an AI. Start from the template:

```bash
cp -r <unikit>/docs/layer-template ~/code/acme-layer   # then rename "example" everywhere
cd ~/code/acme-layer && git init
uk layer check .                                       # well formed, no clashes
```

## What a layer can hold

All optional. A layer with none of these is an error (`uk doctor` says so).

| Path | What unikit does with it |
|---|---|
| `bin/<command>` | on PATH in every shell, **after** unikit's own folders: a command unikit has never runs from a layer. The `commands` part also links it into `~/.local/bin` (not where another program has the name). `bin/fk-<name>` is also `fk <name>` (not `fk-install`, `fk-uninstall`, `fk-help`: those are fk's) |
| `shell/init.sh` | sourced by every bash and zsh, before unikit's tools load: settings they read (`OKTA_AWSCLI_*`, `KX_ALIAS_RULES`, …), aliases. Layers load by name, the ones in its `requires` before it. Runs in every new terminal: keep it fast and silent |
| `components.sh` | installer parts (below) |
| `kit` | one line, `tk` or `fk`: the kit its parts go to (default `tk`). A part can name its own: `kit_<id>() { echo fk; }` |
| `tools` | a line per command for the kit's picker and help: `name\|group\|what it does\|program it needs[\|kit]` |
| `requires` | other layers it needs, one name per line. A layer should need only unikit; `uk doctor` and `uk layer add` say when one is missing |
| `workspaces` | a shared `ws` list (folder and GitHub repo per line); `@<name>` in a person's own list brings it in |
| `claude/skills/<skill>/SKILL.md` | Claude Code skills, linked by unikit's `claude-skill` part (a picker of skills and profiles). A skill lives with the command it documents |
| `README.md` | its first paragraph is the about card in `uk layers` (alt-i) |
| `VERSION` | optional; shown next to its commit in `uk version` and `uk layers` |

## Installer parts (`components.sh`)

unikit sources it after its own parts, so its helpers are there. A part `<id>` (functions use
`<id>` with `-` as `_`):

```bash
COMPONENTS+=(acme-thing)
label_acme_thing()   { echo "acme-thing"; }                     # short name
title_acme_thing()   { echo "what you get, in plain words"; }
detail_acme_thing()  { echo "~/.config/acme/thing.conf"; }      # what it touches (--details)
state_acme_thing()   { NOTE=""; STATE=missing; }                # installed | partial | missing | n/a
install_acme_thing() { ...; }                                   # ask first; nothing when already done
uninstall_acme_thing() { ...; }                                 # puts back what was there
```

Optional, per part:

| | |
|---|---|
| `group_<id>` | its installer tab (`GROUP_ABOUT[<group>]="one line"` for a new group) |
| `touches_<id>` | what it changes, one per line: a file, or `dconf:/a/path/`. Before it changes something another layer's part set up, the installer asks (below) |
| `addboth_<id>` | sets it up beside the other layer's, when that makes sense ("Add both") |
| `requires_<id>` | what the machine needs: `linux`, `apt`, `gnome` (space separated) |
| `kit_<id>` | `fk` or `tk`, against the layer's `kit` |
| `NEEDS[<id>]="other-id"` | a part that must be set up first |
| `CLASHES+=("id other\|question")` | two parts that shouldn't both be in: asked on the summary |
| `LOOK_PARTS+=(<id>)` | a settings look: keep / re-apply / reset menu |

Helpers (`lib/setup.sh`): `ask "question" [y\|n]`, `choose "question" option…`, `ok`, `skip`, `warn`,
`fail`, `say`, `dry` (true in `--dry-run`), `linked <link> <target>`, `link_file`, `unlink_file`
(backs up a real file first, puts it back after), `set_block <file> <body>`, `has_block`,
`drop_block` (unikit's marked block in an rc file: **one per file**, so declare the file in
`touches_`), `apt_install`, `as_root`, `backup`.

Rules every part keeps:

- **Ask before changing anything**; risky things default to No. `--yes` answers yes,
  `--dry-run` changes nothing and says what it would do.
- **Run it twice, nothing changes** the second time: check first, change only what's missing.
- **Uninstall puts back** what was there (the helpers keep backups for you).
- **Every choice is a picker** (`ask`, `choose`, `confirm`, `ui_ask`), never a typed y/N.
- **Names start with the layer's name**: parts, functions, variables, commands.

## Living next to other layers

| What clashes | What happens |
|---|---|
| a part name unikit or another layer has | the loader leaves **all** this layer's parts out, with one line; `uk doctor` names it |
| a file or dconf path another layer's part set up (from `touches_`) | the installer asks: **Skip it** (default; `--yes` and dry runs skip too), **Replace** theirs (backups as always), or **Add both** (with `addboth_<id>`) |
| a command unikit has | never runs from the layer (unikit is first on PATH); `uk doctor` says so |
| a command another layer has | the first on PATH runs; `uk doctor` says so |
| a layer it needs isn't there | `uk doctor` and `uk layer add` say so |
| what `shell/init.sh` sets | not checked: the last layer sourced wins. Prefix with the layer's name |

## Trust: what people see before your code runs

A layer's code runs on the machine of whoever adds it: `shell/init.sh` in every shell, its
commands, `components.sh` whenever the installer or `tk` runs, its skills as instructions to Claude.

- `uk layer add` clones it aside, shows where it's from, the commit, and that list, then asks
  (default No). Yes pins the commit in `layers.lock` (in their unikit folder, not in git).
- `uk update` lists a layer whose **code** changed since the pin unticked, the changed files under
  the cursor and the diff on alt-i; ticking it trusts it and moves the pin. Docs (`*.md` at the top,
  `docs/`) and the plain lists (`tools`, `kit`, `requires`, `workspaces`, `VERSION`) aren't code.
  `--yes` pulls everything else and holds those back.
- `uk doctor` says when a layer moved past its pin some other way (a `git pull` by hand, or commits
  made in it): `uk update` shows those and moves the pin.

So: small commits that say what they change, and code changes kept apart from doc changes,
make your layer quick to trust.

## Checking it

```bash
uk layer check ~/code/acme-layer    # before you push: shape, tools lines, commands, part names
uk layer add <url> && uk doctor     # on a machine: the whole, pins included
tk install --dry-run --layer=acme   # its parts, nothing changed
```

`uk layer check` checks a folder anywhere against unikit and the layers there (a copy of the same
layer in `layers/` aside): what `uk doctor` checks for one layer, plus its part names.
