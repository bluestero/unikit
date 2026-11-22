"""Installer parts' own checks, in a scratch copy of the repo (bluefeels included) with a scratch
HOME: looks (a missing preset, files copied out of the repo), kitty accents without a background.conf, uk layer rm's advice, zsh-hook replacing the older ~/.zshrc line, commands linking the layers' commands."""
import os
import shutil
import subprocess

from fixture import REPO


def copy(sb):
    dst = sb.root + "/repo"
    shutil.copytree(REPO, dst, ignore=shutil.ignore_patterns(".git", "layers.lock", "tests", "tasks", "airpr", "*.zip"))
    return dst


def no_host_tk(sb):
    """PATH without any folder of the machine's that has a tk (~/.local/bin, the toolkit's bin)."""
    sb.env["PATH"] = ":".join(p for p in sb.env["PATH"].split(":") if not os.access(os.path.join(p, "tk"), os.X_OK))


def sh(sb, repo, script):
    """Runs bash with the installer's libraries loaded; returns its output."""
    pre = f'repo={repo} mode=yes details=0; . "$repo/lib/setup.sh"; . "$repo/lib/components.sh"\n'
    p = subprocess.run(["bash", "-c", pre + script], env=sb.env, cwd=sb.home, capture_output=True, text=True,
                       timeout=60, stdin=subprocess.DEVNULL)
    return p.stdout + p.stderr


def install(sb, repo, *parts):
    p = subprocess.run([repo + "/install.sh", "--yes", *parts], env=sb.env, cwd=sb.home, capture_output=True,
                       text=True, timeout=60, stdin=subprocess.DEVNULL)
    assert p.returncode == 0, p.stdout + p.stderr
    return p.stdout


def test_a_missing_look_is_never_applied(sb):
    repo = copy(sb)
    out = sh(sb, repo, 'look_applied /org/x/ /no/such/settings.dconf && echo applied || echo not;'
                       ' look_apply /org/x/ /no/such/settings.dconf x || echo failed')
    assert "not" in out and "failed" in out and "missing" in out, out
    assert not any("load" in c for c in sb.calls("dconf")), sb.calls("dconf")


def test_a_look_file_is_copied_out_of_the_repo(sb):
    repo = copy(sb)
    look = repo + "/layers/bluefeels/gnome/dash-to-panel/settings.dconf"
    out = sh(sb, repo, f'look_apply /org/x/ {look} dash-to-panel && look_file {look} | grep show-apps-icon-file')
    copied = sb.path("~/.local/share/work-toolkit/looks/dash-to-panel/apps-button.svg")
    assert os.path.isfile(copied), out
    assert copied in out and repo not in out, out
    shutil.rmtree(repo + "/layers/bluefeels/gnome/dash-to-panel")   # the layer's files gone: the icon stays
    assert os.path.isfile(copied)


def test_kitty_accents_need_a_background_conf(sb):
    repo = copy(sb)
    sb.fake("kitty", "exit 0")
    install(sb, repo, "kitty-config")
    out = sh(sb, repo, 'component_state kitty-accents; echo "$STATE"; uninstall_kitty_accents')
    assert out.splitlines()[0] == "missing", out          # k-bg reads a missing file as accents on
    assert not os.path.exists(sb.path("~/.config/kitty/background.conf")), "the uninstall must not make one"


def test_layer_rm_names_the_layers_own_uninstall(sb):
    repo = copy(sb)
    p = subprocess.run([repo + "/bin/uk", "layer", "rm", "bluefeels"], env=sb.env, cwd=sb.home, capture_output=True,
                       text=True, timeout=60, stdin=subprocess.DEVNULL)
    assert "fk uninstall" in p.stdout + p.stderr, p.stdout + p.stderr
    assert os.path.isdir(repo + "/layers/bluefeels"), "no terminal to confirm in: nothing removed"


def test_zsh_hook_replaces_the_older_line(sb):
    repo = copy(sb)
    old = f'# >>> work toolkit >>>\n[ -f "{repo}/zsh/zshrc" ] && . "{repo}/zsh/zshrc"\n# <<< work toolkit <<<\n'
    sb.write("~/.zshrc", "export MINE=1\n" + old)
    out = sh(sb, repo, 'component_state zsh-hook; echo "$STATE|$NOTE"')
    assert out.strip() == "partial|~/.zshrc has the older line: set up again to replace it", out
    install(sb, repo, "zsh-hook")
    rc = sb.read("~/.zshrc")
    assert f'. "{repo}/shell/init.sh"' in rc and "zsh/zshrc" not in rc and rc.startswith("export MINE=1\n"), rc
    assert "emulate sh -c '. ~/.profile'" in sb.read("~/.zprofile")
    out = sh(sb, repo, 'component_state zsh-hook; echo "$STATE"; uninstall_zsh_hook >/dev/null; component_state zsh-hook; echo "$STATE"')
    assert out.split() == ["installed", "missing"], out
    assert sb.read("~/.zshrc").strip() == "export MINE=1", sb.read("~/.zshrc")
    assert sh(sb, repo, "touches_zsh").strip() == sb.path("~/.zshenv")   # the zsh part no longer writes ~/.zshrc


def test_commands_links_the_layers_commands(sb):
    repo = copy(sb)
    no_host_tk(sb)
    sb.env["PATH"] = ":".join(p for p in sb.env["PATH"].split(":") if not p.startswith(REPO))   # the host's layers
    sb.fake("k-rofi", "exit 0")                                     # another program has this name
    out = install(sb, repo, "commands")
    link = lambda n: os.path.realpath(sb.path("~/.local/bin/" + n))
    assert link("k-bg") == os.path.realpath(repo + "/layers/bluefeels/bin/k-bg"), out
    assert link("uk") == os.path.realpath(repo + "/bin/uk"), out
    assert not os.path.lexists(sb.path("~/.local/bin/k-rofi")) and "k-rofi is already" in out, out
    out = sh(sb, repo, 'component_state commands; echo "$STATE"; uninstall_commands >/dev/null')
    assert out.strip() == "installed", out
    assert not os.path.lexists(sb.path("~/.local/bin/k-bg")) and not os.path.lexists(sb.path("~/.local/bin/uk"))
