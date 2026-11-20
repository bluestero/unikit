"""uk, unikit's base command, in a scratch copy of the repo with no layers but the test's own:
help and version; uk layer add / rm without a terminal; the uk layers list (about card, add,
remove); uk doctor on a well formed layer and a broken one; tk layer is gone; the installers'
LAYER column; the long command names never take a name another program has."""
import os
import re
import shutil
import subprocess

from fixture import REPO
from term import Term

GIT = ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "init.defaultBranch=main"]


def copy(sb):
    dst = sb.root + "/repo"
    shutil.copytree(REPO, dst, ignore=shutil.ignore_patterns(".git", "tests", "tasks", "layers", "*.zip"))
    return dst


def source(sb, name, kit=None, part=False):
    """A layer's own git repo (to clone from): a command, its tools line, maybe a part."""
    d = f"{sb.root}/src/{name}"
    os.makedirs(d + "/bin")
    with open(d + "/bin/hello-" + name, "w") as f:
        f.write("#!/bin/sh\necho hello\n")
    os.chmod(d + "/bin/hello-" + name, 0o755)
    with open(d + "/tools", "w") as f:
        f.write(f"hello-{name}|Work|says hello|\n")
    with open(d + "/README.md", "w") as f:
        f.write(f"# {name}\n\nA layer for [unikit](https://example.com) that says hello.\n")
    if kit:
        with open(d + "/kit", "w") as f:
            f.write(kit + "\n")
    if part:
        p = name.replace("-", "_")
        with open(d + "/components.sh", "w") as f:
            f.write(f'COMPONENTS+=({name}-part)\ngroup_{p}_part() {{ echo Demo; }}\n'
                    f'label_{p}_part() {{ echo Demo; }}; title_{p}_part() {{ echo "a part"; }}\n'
                    f'detail_{p}_part() {{ echo nothing; }}; state_{p}_part() {{ STATE=missing NOTE=""; }}\n'
                    f'install_{p}_part() {{ :; }}; uninstall_{p}_part() {{ :; }}\n')
    subprocess.run(["git", "init", "-q", d], check=True, env=sb.env)
    subprocess.run(GIT + ["-C", d, "add", "-A"], check=True, env=sb.env)
    subprocess.run(GIT + ["-C", d, "commit", "-qm", "first"], check=True, env=sb.env)
    return d


def run(sb, repo, cmd, *args):
    p = subprocess.run([repo + "/bin/" + cmd, *args], env=sb.env, cwd=sb.home, capture_output=True,
                       text=True, stdin=subprocess.DEVNULL, timeout=60)
    return p.returncode, p.stdout + p.stderr


def test_help_version_and_no_layers(sb):
    repo = copy(sb)
    code, out = run(sb, repo, "uk", "help")
    assert code == 0 and "uk layers" in out and "uk doctor" in out and "uk version" in out, out
    code, out = run(sb, repo, "uk", "version")
    assert code == 0 and out.startswith("unikit "), out
    code, out = run(sb, repo, "uk", "layers")
    assert code == 0 and "No layers yet" in out, out


def test_layer_add_and_rm_without_a_terminal(sb):
    repo = copy(sb)
    src = source(sb, "unix-acme-toolkit")
    code, out = run(sb, repo, "uk", "layer", "add", src)
    assert code == 0 and "layer acme added" in out and "Later: tk install --layer=acme" in out, out
    assert os.path.isfile(repo + "/layers/acme/tools")
    code, out = run(sb, repo, "uk", "layers")
    assert "acme" in out and src in out, out
    code, out = run(sb, repo, "uk", "layer", "rm", "acme")
    assert "Kept." in out and os.path.isdir(repo + "/layers/acme"), "no terminal to confirm in: nothing removed"
    code, out = run(sb, repo, "uk", "layer", "add", src)
    assert code == 1 and "already there" in out, out


def test_tk_layer_is_gone(sb):
    repo = copy(sb)
    code, out = run(sb, repo, "tk", "layer", "ls")
    assert code == 1 and "uk layers" in out, out
    code, out = run(sb, repo, "tk", "help")
    assert "tk layer" not in out, out


def test_doctor_passes_a_good_layer_and_names_a_broken_ones_faults(sb):
    repo = copy(sb)
    sb.add_path(repo + "/bin")
    subprocess.run(GIT + ["clone", "-q", source(sb, "good", part=True), repo + "/layers/good"], check=True, env=sb.env)
    code, out = run(sb, repo, "uk", "doctor")
    assert code == 0 and "good" in out and "!" not in out, out
    bad = repo + "/layers/bad"
    os.makedirs(bad + "/bin")
    with open(bad + "/kit", "w") as f:
        f.write("gk\n")
    for name in ("fk-install", "tk", "hello-good", "notrun"):
        with open(bad + "/bin/" + name, "w") as f:
            f.write("#!/bin/sh\n")
        if name != "notrun":
            os.chmod(bad + "/bin/" + name, 0o755)
    with open(bad + "/tools", "w") as f:
        f.write("nowhere|Work|a command it doesn't have|\nhalf|Work\n")
    code, out = run(sb, repo, "uk", "doctor")
    assert code == 1, out
    for fault in ("kit file says 'gk'", "bin/fk-install never runs", "bin/tk never runs: unikit's tk comes first",
                  "bin/hello-good: bad has a hello-good too", "bin/notrun isn't executable",
                  "there's no bin/nowhere", "tools line 'half|Work' needs"):
        assert fault in out or fault.replace("bad has", "good has") in out, (fault, out)


def test_the_installers_name_each_parts_layer(sb):
    repo = copy(sb)
    subprocess.run(GIT + ["clone", "-q", source(sb, "demo", part=True), repo + "/layers/demo"], check=True, env=sb.env)
    _, out = run(sb, repo, "../install.sh", "ls")
    assert re.search(r"COMPONENT\s+LAYER\s+STATE", out), out
    assert re.search(r"^  bash\s+unikit\s", out, re.M) and re.search(r"^  demo-part\s+demo\s", out, re.M), out
    t = Term([repo + "/install.sh", "--layer=demo"], sb.env, cols=120, rows=30, cwd=sb.home)
    t.wait_for("enter to the summary", timeout=20)
    t.wait(lambda t: "LAYER" in t.text() and re.search(r"demo-part\s+○ not installed\s+demo\s", t.text()),
           what="demo-part's row with its layer")
    t.key("esc")
    t.wait_exit()


def test_list_shows_about_adds_and_removes(sb):
    repo = copy(sb)
    subprocess.run(GIT + ["clone", "-q", source(sb, "look", kit="fk"), repo + "/layers/look"], check=True, env=sb.env)
    src = source(sb, "unix-acme-toolkit")
    t = Term([repo + "/bin/uk", "layers"], sb.env, cols=140, rows=30, cwd=sb.home)
    t.wait_for("look")
    t.settle()
    assert re.search(r"look\s+fk\s", t.text()), t.text()          # FEEDS: its tools line is fk's
    t.key("alt-i")                                                # the about card
    t.wait_for("that says hello")
    t.wait_for("hello-look")
    t.key("alt-i")
    t.wait_gone("that says hello")
    t.key("alt-a")
    t.wait_for("git URL?")
    t.key(src, "enter")
    t.wait_for("Added acme")
    t.key("n")
    t.wait_for("layer acme added")
    assert os.path.isfile(repo + "/layers/acme/tools")
    t.wait(lambda t: "acme" in t.cursor_line(), what="the cursor on the new layer")
    t.key("enter")
    t.wait_for("Remove this layer")
    t.key("down", "down", "enter")
    t.wait_for("Remove the acme layer?")
    t.key("y")
    t.wait_for("layer acme removed")
    assert not os.path.exists(repo + "/layers/acme")
    t.key("esc")
    assert t.wait_exit() == 0


def test_a_long_name_another_program_has_is_left_alone(sb):
    repo = copy(sb)
    sb.fake("toolkit", "exit 0")
    _, out = run(sb, repo, "../install.sh", "--yes", "commands")
    assert "toolkit is already" in out, out
    assert not os.path.lexists(sb.path("~/.local/bin/toolkit"))
    assert os.path.realpath(sb.path("~/.local/bin/unikit")) == os.path.realpath(repo + "/bin/uk")
    assert os.path.realpath(sb.path("~/.local/bin/uk")) == os.path.realpath(repo + "/bin/uk")
