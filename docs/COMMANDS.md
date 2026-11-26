# Commands

Everything `uk`, `tk` and `fk` do. The [README](../README.md#everyday-commands) has the short list.

- [uk: the base](#uk-the-base)
- [tk and fk: the kits](#tk-and-fk-the-kits)
- [Presets: `<kit> configs`](#presets-kit-configs)
- [Your workspace list](#your-workspace-list)

The long names `unikit`, `toolkit` and `feelkit` (for `uk`, `tk`, `fk`) are linked by the `commands`
part, only where no other program has the name.

## uk: the base

| Command | What it does |
|---|---|
| `uk status` | the folder, the layers, how much of each kit is set up ("6 of 11 parts set up → fk install"), the version |
| `uk layers` | lists the layers: what's there, the kits it feeds, where from, which version. enter: set up or remove its parts, or remove it; alt-a adds one; alt-i shows what each one is |
| `uk layer add <name or git URL>` | `bluetools` and `bluefeels` by name, any other by its git URL: clones it into `layers/<name>` (a `unix-` prefix and `-toolkit` are dropped), shows what runs here, asks, offers to set it up |
| `uk layer rm <name>` | deletes it (refuses while it has unpushed work) |
| `uk layer check <dir>` | checks a layer you're making before you push it: well formed, no clashes with unikit or the layers here |
| `uk doctor` | checks the whole: the commands are unikit's, each layer is well formed and at the commit you trusted, no two bring the same part or command |
| `uk update` | pulls what's new in unikit and each layer, showing changed code first ([how it works](INSTALL.md#updates)) |
| `uk skills` | picks which Claude profiles get which skills and plugins, with the layer each comes from. ctrl-p: the details pane |
| `uk skills ls` | the same as a table |
| `uk skills <name>` | one of them |
| `uk version` | unikit's version and each layer's |

## tk and fk: the kits

`tk` (toolkit) is what you work with; `fk` (feelkit) is how it looks. They are siblings with the
same words:

| Command | What it does |
|---|---|
| `<kit>` | picks and runs any of its commands |
| `<kit> ls` | lists them: what each does, its layer, ready or not |
| `<kit> install`, `<kit> uninstall` | set up and remove its parts ([the installer](INSTALL.md#the-installer)) |
| `<kit> doctor` | checks its commands and parts in one box |
| `<kit> configs` | switches the presets its parts bring ([below](#presets-kit-configs)) |
| `<kit> help` | shows it all |
| `<kit> <name>` | a layer's `<kit>/<name>` command |

A kit with no layers says so: "Nothing here yet. Add a layer: uk layers".

A layer's parts go to the kit in its `kit` file (`tk` without one), or a part names its own.
`tk install` sets up the tk parts and `fk install` the fk parts, from unikit and every layer, and
each leaves the other's out.

## Presets: `<kit> configs`

Each preset the kit's parts bring can be switched between:

- **the layer's preset**
- **the app's own default**
- **what you had before**
- **one step back**

The app stays installed either way. "Edited preset" means you changed the layer's copy (a link into
its repo).

**Edit my patch** keeps your own changes in `~/.config/unikit/patches/`. The toolkit never touches
them, and they're read after the preset, so they win.

## Your workspace list

Your list is `~/.config/ws/workspaces`, outside the repo, so it's yours to edit (bluetools' `ws edit`)
and updates never change it. bluetools' `ws` opens what's in it, and its `repos` part clones any listed
repo you don't have yet. Any layer reads its variables (`ws_var NAME`, `lib/workspaces.sh`).

A line `NAME=folder` sets a folder the paths below can use as `$NAME`, and `@<layer>` brings in a
layer's shared list:

```
ACME=~/work/acme                  # where the "acme" layer's repos go; change it to keep them elsewhere
@acme                             # that layer's shared list (layers/acme/workspaces); delete to leave it out
~/code/my-project   me/my-project # your own: a folder, then optionally its GitHub repo to clone
```

A new list starts with one such pair per layer you have. New team repos go in the layer's
`workspaces` file, so everyone gets them on `uk update`.
