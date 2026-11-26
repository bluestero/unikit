# Installing, updating and removing

The short version is in the [README](../README.md#get-it). This page has the details.

- [What it runs on](#what-it-runs-on)
- [Get it](#get-it)
- [Set up the parts](#set-up-the-parts)
- [Updates](#updates)
- [Removing it, and going back to your own setup](#removing-it-and-going-back-to-your-own-setup)
- [unikit's own parts](#unikits-own-parts)

## What it runs on

Ubuntu with GNOME. bluefeels' desktop parts need GNOME; unikit and bluetools need only bash and
Linux. On other systems the installer checks each part against the machine and marks what can't
run there `⊘ not supported here`, with the reason.

You need git and curl (`sudo apt install git curl`). Whatever the layers' tools run on comes with
their parts: the latest release for your CPU, in `~/.local`, with no sudo where it can.

## Get it

```bash
git clone https://github.com/bluestero/unikit.git ~/unikit   # any folder you'll keep: the commands point into it
~/unikit/install.sh
```

**The first run** (no layers yet) starts with a list of the layers unikit knows, bluetools and
bluefeels, nothing ticked. The ones you tick are added (each shows what of it runs here and asks
first), then the installer goes on with their parts. Skip them and the list comes back next run,
until there's a layer. Its `commands` part puts `uk`, `tk` and `fk` in `~/.local/bin`.

**Adding a layer later:** `uk layer add bluetools` (or `bluefeels`; any other layer by its git URL), or
alt-a in `uk layers`. It shows what of the layer runs here, asks, and offers to set up its parts.

**Or in one line**, with `bootstrap.sh`: it clones unikit into `~/.local/share/unikit` (or updates it if
it's there), adds the `tk` command and the layers you name. Nothing else changes yet; `tk install` next.

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/bluestero/unikit/main/bootstrap.sh) --layer bluetools --layer bluefeels
```

| Option | What it does |
|---|---|
| `--dir <folder>` | puts unikit somewhere else |
| `--layer <name or git URL>` | adds a layer (`bluetools` and `bluefeels` by name); repeat it for more |

## Set up the parts

```bash
tk install      # unikit's own parts and the tk layers' (bluetools)
fk install      # the fk layers' (bluefeels)
```

Then open a new terminal. `uk status` shows how much of each kit is set up; `tk doctor` and
`fk doctor` list anything left, each with the command that fixes it. Each layer's README says how to
start with its tools.

### The installer

```bash
./install.sh ls          # what's installed
./install.sh             # a tab per group: tick what to set up, then one question per change (Enter = yes)
./install.sh fzf         # just one part (fk install <part> for an fk one)
./install.sh --dry-run   # preview; --details also shows diffs
./uninstall.sh           # the same tabs: tick what's installed, enter removes it
./install.sh --plain     # never use or offer gum
```

`tk install` and `fk install` are the same installer, each with its own kit's parts.

- **Tabs.** It opens on a tab per group: unikit's Recommended and Claude Code, then the groups its
  layers' parts name (the fk kit's parts have their own: `fk install`). ←/→ change tabs.
- **Each tab** says in one line what the group is, then lists its parts with their state (installed,
  partly, not installed, needs `<part>`, not supported here), what each gets you, and which layer it
  comes from (LAYER; `unikit` for the base's own). The footer shows what the part under the cursor
  touches on disk.
- **Ticking.** Nothing starts ticked: Tab ticks a part. A part that needs another one (bluefeels'
  yazi-keys needs yazi) can still be ticked: that ticks the other one too, and the run sets it up
  first. "Not supported here" means this machine can't run it (no GNOME, say).
- **Summary.** Enter goes to the Summary tab: everything that will be set up, with what `--dry-run`
  prints for the part under the cursor. Enter there sets it up, and each change still asks first
  (Enter = yes). Esc anywhere leaves with nothing changed.
- **Parts that clash.** Some parts shouldn't both be in (bluefeels' Dash2Dock and Dash to Panel).
  With one ticked and the other ticked or already in, the summary asks once whether to keep both
  (No goes back to their tab).
- **Needs fzf 0.63+** (`./install.sh fzf`); with an older fzf it's one checklist instead.
- **gum.** If [gum](https://github.com/charmbracelet/gum) isn't installed, the installer offers to
  fetch it (v2.0.2, checksum-checked, into `~/.local/bin`, no sudo) for nicer questions and the
  checklist. Say no and the plain built-in ones are used. Remove it with `rm ~/.local/bin/gum`.

Both install and uninstall are safe to run any number of times: they check first and only touch
what's missing (or still there). Replaced files are backed up as `<file>.bak-<time>`, and uninstall
puts the backup back. Log: `~/.local/state/unikit/setup.log`.

## Updates

```bash
uk update
```

1. **What's new.** It looks for updates to unikit and every layer and lists the ones with new
   commits (each one's commits under the cursor), ticked. Untick one to hold it back; keep unikit
   ticked when you pull a layer, since layers may need it. Enter pulls the rest.
2. **Changed code waits for you.** A layer whose code changed since you last trusted it (its pin in
   `layers.lock`) starts unticked, with the changed files under the cursor. alt-i shows their diff,
   and ticking it trusts them: its pin moves to what it pulled. Docs and the plain lists (`tools`,
   `kit`, `requires`, `workspaces`, `VERSION`) don't count as code. `--yes` pulls everything else
   and holds those back.
3. **Every part, checked.** Then it lists every part, one tab per repo:
   - up to date
   - updated: the pull changed its files; nothing to do
   - needs a fix: the pull broke it, or a link it made now points nowhere
   - new
   - removed upstream: it cleans up the links that part left

   Fixes and clean-ups start ticked; new parts don't; each change still asks.

Nothing changes without asking, and a second run changes nothing.

## Removing it, and going back to your own setup

`tk uninstall` (and `fk uninstall`) opens the installer's tabs, a tab per group: tick what's
installed (ticking a part ticks the parts that need it), then enter on the summary removes it.

The first time the installer changes something of yours, it keeps what you had in
`~/.local/state/unikit/originals/` (once, never overwritten). Uninstalling unikit's parts puts back:

| What | Put back on uninstall |
|---|---|
| `~/.bashrc` | only unikit's line is removed |
| `~/.zshrc`, `~/.zprofile` | only unikit's marked block is removed |
| `fzf` | apt's again |
| Claude Code skills and plugins | the links to the layers' skills, and the plugins the layers list |

Each layer's README says what its own parts put back.

## unikit's own parts

| Part | What it sets up |
|---|---|
| `bash` | `~/.bashrc` gets one line loading `shell/init.sh` (and so every layer); uninstall takes it out |
| `zsh-hook` | `~/.zshrc` gets one managed block loading `shell/init.sh` (like bash's line); `~/.zprofile` one reading `~/.profile` |
| `commands` | `uk`, `tk`, `fk` and every layer's `bin/` commands in `~/.local/bin` (for scripts and other programs); the long names `unikit`, `toolkit`, `feelkit` too. A name another program has is left alone |
| `fzf` | fzf 0.74.5 from GitHub (checksum-checked) in `~/.local/bin`, ahead of Ubuntu's 0.44. Every picker then shows where you are (`12/426`, `3/17 of 426` while searching), and bluefeels' k-theme gets its tabs. Uninstall goes back to apt's |
| `claude-skill` | links each layer's skills into Claude Code (see below) and installs the plugins its `claude/plugins` lists |

**`claude-skill` in detail.** It links each layer's skills (`claude/skills/<name>`) into Claude Code's
skills (`$CLAUDE_CONFIG_DIR`, else `~/.claude`, and every profile in `~/.claude-profiles`), and installs
the plugins its `claude/plugins` lists (`claude plugin install`, from their authors' GitHub repos;
picked in the list only, `--yes` sets up the skills). In a terminal it's a picker: the skills and
plugins (their type, layer, which profiles have them; ✓ in every profile, ◐ in some), then which
profiles get them. alt-g picks exact profile/skill pairs instead, and unticking one that's there
removes it (asked first, default No). `uk skills` opens the same picker any time.
