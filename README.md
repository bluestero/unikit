# unikit

The base of a shell toolkit, and nothing more: `uk` manages the layers, and the two kits, `tk`
(what you work with) and `fk` (how it looks), are filled by them. A **layer** is a repo of its own
that brings commands, installer parts, shell settings and Claude skills; unikit finds them by
their place and never changes for one. Anyone can write one, for either kit or both
([docs/LAYERS.md](docs/LAYERS.md)).

| Layer | Kit | What it brings |
|---|---|---|
| [bluetools](https://github.com/bluestero/bluetools) | tk | `okcli` (Okta AWS profiles), `kx` (Kubernetes per terminal), `twin` (Twingate), `ws` (workspaces in your IDE), `hat` (Claude, GitHub and AWS per folder), `ctx` (where am I), Claude Code's start hook and PROD guard, the `bluetools` skill |
| [bluefeels](https://github.com/bluestero/bluefeels) | fk | kitty (config, background, theme, icons), the shell (starship, zsh, keys, btop, yazi), the GNOME desktop (rofi launcher, app keys, extensions and their looks), Claude guidelines |
| your company's | either | its settings, team repos and commands (e.g. airpr: AirPR's containers, Postman, repos) |

| Command | What it does |
|---|---|
| `uk` | unikit, the base under the two kits (`tk`, `fk`): `uk status` shows the folder, the layers, how much of each kit is set up and the version, `uk layers` lists the [layers](#layers) (enter: set up or remove its parts, remove it; alt-a adds one; alt-i shows what each one is), `uk doctor` checks the whole (the commands are unikit's, each layer is well formed and at the commit you trusted, no two bring the same part or command), `uk layer check <dir>` checks a layer you're making before you push it, `uk update` pulls what's new in unikit and each layer (see Updates), `uk skills` picks which Claude profiles get which skills and plugins, with the layer each comes from (ctrl-p: the details pane; `uk skills ls` a table, `uk skills <name>` one of them), `uk version` shows unikit's version and each layer's. The long names `unikit`, `toolkit` and `feelkit` (for `uk`, `tk`, `fk`) are linked by the commands part, only where no other program has the name. |
| `tk`, `fk` | The two kits, siblings with the same words: `<kit>` picks and runs any of its commands, `<kit> ls` lists them (what each does, its layer, ready or not), `<kit> install` / `<kit> uninstall` set up and remove its parts, `<kit> doctor` checks its commands and parts in one box, `<kit> help` shows it all, and a layer's `<kit>/<name>` is `<kit> <name>`. `<kit> configs` switches each preset its parts bring between the layer's preset, the app's own default, what you had before, or one step back (the app stays installed; "edited preset" means you changed the layer's copy, a link into its repo); "Edit my patch" keeps your own changes in `~/.config/unikit/patches/`, never touched by the toolkit and read after the preset so they win. A kit with no layers says so ("Nothing here yet. Add a layer: uk layers"). |

## Set it up on your machine

For Ubuntu with GNOME (bluefeels' desktop parts need it; unikit and bluetools need only bash and
Linux). Nothing changes without asking first. On other systems the installer checks each part
against the machine and marks what can't run there `⊘ not supported here`, with the reason.

**1. Have git and curl** (`sudo apt install git curl`). Whatever the layers' tools run on comes with
their parts, the latest release for your CPU, in `~/.local` with no sudo where it can.

**2. Get it.** One command: it clones unikit into `~/.local/share/unikit` (or updates it if
it's there), adds the `tk` command, and adds the layers you name. Nothing else changes yet.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bluestero/unikit/main/bootstrap.sh) --layer bluetools --layer bluefeels
```

`--dir <folder>` puts it elsewhere. `--layer <name or git URL>` adds a layer (`bluetools` and
`bluefeels` by name; repeat it for more). Or step by step (over SSH: needs an SSH key on your
GitHub account, `ssh -T git@github.com` checks it):

```bash
git clone git@github.com:bluestero/unikit.git ~/.local/share/unikit
mkdir -p ~/.local/bin && ln -sfn ~/.local/share/unikit/bin/tk ~/.local/bin/tk
~/.local/share/unikit/bin/uk layer add git@github.com:bluestero/bluetools.git
```

Layers are added the same way later: `uk layer add <git URL>`, or alt-a in `uk layers`. It shows
what of the layer runs here, asks, and offers to set up its parts.

**3. Install.** A tab per group of parts. Nothing is ticked: tick what you want with Tab, then
Enter twice (to the summary, then set up). Each change still asks first (Enter = yes).

```bash
tk install      # unikit's own parts and the tk layers' (bluetools)
fk install      # the fk layers' (bluefeels)
```

**4. Open a new terminal and check.** `uk status` shows how much of each kit is set up; `tk doctor`
and `fk doctor` list anything left, each with the command that fixes it. Each layer's README says
how to start with its tools.

**Your workspace list** is `~/.config/ws/workspaces`, outside the repo, so it's yours to edit
(bluetools' `ws edit`) and updates never change it. bluetools' `ws` opens what's in it and its
`repos` part clones any listed repo you don't have yet; any layer reads its variables (`ws_var NAME`,
`lib/workspaces.sh`). A line `NAME=folder` sets a folder the paths below can use
as `$NAME`, and `@<layer>` brings in a layer's shared list:

```
ACME=~/work/acme                  # where the "acme" layer's repos go; change it to keep them elsewhere
@acme                             # that layer's shared list (layers/acme/workspaces); delete to leave it out
~/code/my-project   me/my-project # your own: a folder, then optionally its GitHub repo to clone
```

A new list starts with one such pair per layer you have. New team repos go in the layer's
`workspaces` file, so everyone gets them on `uk update`.

**Updates:** `uk update` looks for updates to unikit and every layer (bluefeels too) and lists the ones with new commits (each one's commits under the cursor), ticked: untick one to hold it back (keep unikit ticked when you pull a layer: layers may need it), enter pulls the rest. A layer whose code changed since you last trusted it (its pin in `layers.lock`: anything but its docs and its `tools`, `kit`, `requires`, `workspaces`, `VERSION` lists) starts unticked, with the changed files under the cursor; alt-i shows their diff, and ticking it trusts them (its pin moves to what it pulled). `--yes` pulls everything else and holds those back. Then it lists every part, one tab per repo: up to date, updated (the pull changed its files; nothing to do), needs a fix (the pull broke it, or a link it made now points nowhere), new, or removed upstream (it cleans up the links that part left). Fixes and clean-ups start ticked; new parts don't; each change still asks. Nothing changes without asking, and a second run changes nothing. Maintainers: rename, move or drop a part's files freely: the installer records every link it makes (`~/.local/state/unikit/links`), so `uk update` finds the ones left pointing nowhere. What isn't a link (dconf, apt, dotfile blocks) a dropped part can't clean up after the pull, so drop those by hand. Maintainers: bump `VERSION` (1.2.0 → 1.3.0 for new things, → 1.2.1 for fixes) when you push something the team will notice.

**Removing it:** `tk uninstall` shows a checklist of what's installed, and puts back what you had
before (see [Going back to your own setup](#going-back-to-your-own-setup)).

## Layers

A layer is a folder in `layers/<name>/`, from its own repo, that adds to the toolkit without
changing it: a company's settings, team repos and commands stay in a private repo, and the
toolkit stays general. `layers/` is gitignored; there's nothing to register.

```bash
uk layers                                            # the list: what's there, the kits it feeds, where from, which version; alt-i: about it
uk layer add git@github.com:acme/acme-toolkit.git   # clones into layers/acme (a unix- prefix and -toolkit are dropped), asks, offers to set it up
uk layer rm acme                                     # deletes it (refuses while it has unpushed work)
uk layer check ~/code/acme-toolkit                   # a layer you're making: well formed, no clashes with unikit or the layers here
```

**Trust.** A layer's code runs on your machine: its `shell/init.sh` in every shell, its commands,
its `components.sh` when you set up its parts, and its Claude skills tell Claude what to do. So
`uk layer add` clones it aside, shows where it's from, at which commit, and all of that, then asks
(default No; no means nothing of it is left). Yes pins that commit in `layers.lock` (in the unikit
folder, not in git). From then on `uk update` shows the code that changed since the pin before it
pulls, and `uk doctor` says when a layer moved past its pin some other way (a `git pull` by hand,
or your own commits): `uk update` shows those changes and moves the pin. Layers added before pins
are pinned where they are on the first `uk update`.

Copying a folder into `layers/` works too (no updates then). Everything in a layer is optional:

| In the layer | What the toolkit does with it |
|---|---|
| `bin/` | on PATH in every shell, after unikit's own (a command unikit has stays unikit's; `uk doctor` names a layer that tries) |
| `tk/`, `fk/` | the kits' subcommands, not on PATH: `tk/<name>` is `tk <name>`, `fk/<name>` `fk <name>` (the kit's own words, `ls`, `install`, `uninstall`, `help`, stay the kit's) |
| `shell/init.sh` | sourced by bash and zsh, layers by name (a layer's `requires` first): its settings, aliases, prompt hooks, completion |
| `components.sh` | installer components (`COMPONENTS+=(…)` and the usual functions; `group_<id>` names its installer tab, `GROUP_ABOUT[<group>]="…"` says what a new group is). A part name unikit or another layer already has leaves this layer's parts out. `touches_<id>` says what a part changes (a file, or `dconf:/a/path/`): before it changes something another layer's part set up, the installer asks: skip it (the default, and what `--yes` does), replace, or add both (when the part has `addboth_<id>`) |
| `tools` | commands for the kit's picker and help (`tk ls`, `tk`; `fk`): `name\|group\|what it does\|program it needs[\|kit]`; without the kit, the layer's |
| `requires` | the layers it needs, one name per line. A layer needs only unikit and itself unless it says so here; `uk doctor` and `uk layer add` say when one isn't there |
| `workspaces` | a shared workspace list (folders, the GitHub repo to clone, `NAME=folder` variables); `@<name>` in your own list brings it in |
| `claude/skills/<skill>/` | Claude Code skills, linked by the `claude-skill` component |
| `claude/plugins` | Claude Code plugins, a line each (`plugin@marketplace\|owner/repo\|what it gives`), installed by the same component |
| `kit` | one line, `tk` or `fk`: the kit this layer's parts go to unless a part says otherwise (`kit_<id>() { echo fk; }`; `tk` without the file). `tk install` sets up the tk parts and `fk install` the fk parts, from the toolkit and every layer, and each leaves the other's out; `uk status` shows both ("6 of 11 parts set up → fk install") |

Writing one? [docs/LAYERS.md](docs/LAYERS.md) is the whole contract (parts, helpers, clashes, trust), and `docs/layer-template/` a working layer to start from (`uk layer check` it before you push). `lib/layers.sh` has the same list in short. A layer's components can also say what
they need from the machine (`requires_<id>`: `gnome`, `apt`, `linux`) and list themselves in
`LOOK_PARTS+=(…)` to get the keep / re-apply / reset settings menu, or name two parts that shouldn't both be in
(`CLASHES+=("id id|the question")`: the installer's summary asks once, default No).
`tk install` and `fk install` show which layer each part comes from (LAYER; `unikit` for the base's own).

### Two kits: tk and fk

`tk` (toolkit) is what you work with; `fk` (feelkit) is how it looks. A layer's parts go to the kit
in its `kit` file (`tk` without one), or a part names its own (`kit_<id>`). `tk install` sets up the
tk parts and `fk install` the fk parts, from unikit and every layer, and each leaves the other's out;
`uk status` shows both.

## Install / uninstall

```bash
./install.sh ls          # what's installed
./install.sh             # a tab per group: tick what to set up, then one question per change (Enter = yes)
./install.sh fzf         # just one part (fk install <part> for an fk one)
./install.sh --dry-run   # preview; --details also shows diffs
./uninstall.sh           # checklist of what's installed; pick what to remove
./install.sh --plain     # never use or offer gum
```

The installer opens on a tab per group (unikit's Recommended and Claude Code, then the groups its
layers' parts name; the fk kit's parts have their own: `fk install`). A tab says in one line what the group is, then lists its parts
with their state (installed, partly, not installed, needs <part>, not supported here) and what each gets you;
a part that needs another one (bluefeels' yazi-keys needs yazi) can still be ticked: ticking it ticks that one too,
and the run sets it up first. Not supported here means this machine can't run it (no GNOME, say); the
footer shows what the part under the cursor touches on disk. ←/→ change tabs, Tab ticks,
Enter goes to the **Summary** tab: everything that will be set up, with what `--dry-run` prints for the
part under the cursor. Enter there sets it up; Esc anywhere leaves with nothing changed. Parts that
shouldn't both be in (bluefeels' Dash2Dock and Dash to Panel: `fk install`), one ticked and the other
ticked or already in, make the summary ask once whether to keep both (No goes back to their tab). Needs fzf 0.63+ (`./install.sh fzf`);
with an older fzf it's one checklist instead. Nothing starts ticked: you pick every part yourself.
If [gum](https://github.com/charmbracelet/gum) isn't installed, the installer offers to fetch it
(v2.0.2, checksum-checked, into `~/.local/bin`, no sudo) for nicer questions (and the checklist); say no
and the plain built-in ones are used. Remove it with `rm ~/.local/bin/gum`.

Both are safe to run any number of times: they check first and only touch what's missing
(or still there). Replaced files are backed up as `<file>.bak-<time>`, and uninstall puts
the backup back. Log: `~/.local/state/unikit/setup.log`.

### Going back to your own setup

The first time the installer changes something of yours, it keeps what you had in
`~/.local/state/unikit/originals/` (once, never overwritten). Uninstalling unikit's parts puts back:

| What | Put back on uninstall |
|---|---|
| `~/.bashrc` | only unikit's line is removed |
| `~/.zshrc`, `~/.zprofile` | only unikit's marked block is removed |
| `fzf` | apt's again |
| Claude Code skills and plugins | the links to the layers' skills, and the plugins the layers list |

Each layer's README says what its own parts put back.

| unikit's parts | What it sets up |
|---|---|
| `bash` | `~/.bashrc` gets one line loading `shell/init.sh` (and so every layer); uninstall takes it out |
| `zsh-hook` | `~/.zshrc` gets one managed block loading `shell/init.sh` (like bash's line); `~/.zprofile` one reading `~/.profile` |
| `commands` | `uk`, `tk`, `fk` and every layer's `bin/` commands in `~/.local/bin` (for scripts and other programs); the long names `unikit`, `toolkit`, `feelkit` too; a name another program has is left alone |
| `fzf` | fzf 0.74.5 from GitHub (checksum-checked) in `~/.local/bin`, ahead of Ubuntu's 0.44. Every picker then shows where you are (`12/426`, `3/17 of 426` while searching), and bluefeels' k-theme gets its tabs. Uninstall goes back to apt's |
| `claude-skill` | Links each layer's skills (`claude/skills/<name>`) into Claude Code's skills (`$CLAUDE_CONFIG_DIR`, else `~/.claude`, and every profile in `~/.claude-profiles`), and installs the plugins its `claude/plugins` lists (`claude plugin install`, from their authors' GitHub repos; picked in the list only, `--yes` sets up the skills). In a terminal it's a picker: the skills and plugins (their type, layer, which profiles have them; ✓ in every profile, ◐ in some), then which profiles get them; alt-g picks exact profile/skill pairs instead, and unticking one that's there removes it (asked first, default No). `uk skills` opens the same picker any time |

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
docs/                       LAYERS.md (writing a layer) and layer-template/
tests/                      kept tests (see below)
```

## Tests

`tests/run.sh` drives the pickers in a pseudo-terminal, with a scratch HOME and fake system commands,
so it never touches your settings, cloud or cluster (needs `uv`). It runs unikit's `tests/cases/` and
each layer's `layers/<name>/tests/cases/`; add a name to run one file (e.g. `tests/run.sh uk`).
`tests/run.sh speed` (and a layer's `speed_<name>`) times keys and start-up against the budgets in
`tests/lib/budget.py`.
