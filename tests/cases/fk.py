"""fk, the feelkit kit's front door, in a scratch copy of the repo with no layers but the
test's own: empty without a look layer; a layer's tools lines fill its picker and help;
a layer's fk/<name> is fk <name>, and fk's own words can't be taken."""
import os
import shutil
import subprocess

from fixture import REPO
from term import Term


def copy(sb, layer=True):
    dst = sb.root + "/repo"
    shutil.copytree(REPO, dst, ignore=shutil.ignore_patterns(".git", "layers.lock", "tests", "tasks", "layers", "*.zip"))
    if layer:   # a look layer: one subcommand, one that tries to take fk install, and their tools lines
        d = dst + "/layers/look"
        os.makedirs(d + "/fk")
        with open(d + "/kit", "w") as f:
            f.write("fk\n")
        for name, body in (("hello", 'echo "hello from the layer: $*"'), ("install", "echo taken")):
            with open(d + "/fk/" + name, "w") as f:
                f.write("#!/bin/sh\n" + body + "\n")
            os.chmod(d + "/fk/" + name, 0o755)
        with open(d + "/tools", "w") as f:
            f.write("fk hello|Desktop|says hello|\nk-work|Work|a tk command|\n")
            f.write("k-tk|Work|a tk command too||tk\n")
    return dst


def run(sb, repo, *args):
    p = subprocess.run([repo + "/bin/fk", *args], env=sb.env, cwd=sb.home, capture_output=True,
                       text=True, stdin=subprocess.DEVNULL, timeout=60)
    return p.returncode, p.stdout + p.stderr


def test_empty_without_a_look_layer(sb):
    repo = copy(sb, layer=False)
    code, out = run(sb, repo, "help")
    assert code == 0 and "Nothing here yet" in out and "fk install" in out, out
    code, out = run(sb, repo, "install")
    assert code == 0 and "fk has no parts yet" in out, out
    code, out = run(sb, repo, "uninstall")
    assert code == 0 and "fk has no parts yet" in out, out


def test_a_layer_fills_help_and_runs_as_a_subcommand(sb):
    repo = copy(sb)
    code, out = run(sb, repo, "help")
    assert "fk hello" in out and "says hello" in out and "Nothing here yet" not in out, out
    assert "k-tk" not in out, "a line that names tk stays out of fk"
    code, out = run(sb, repo, "hello", "a", "b c")
    assert code == 0 and "hello from the layer: a b c" in out, out


def test_fk_words_stay_fks(sb):
    repo = copy(sb)
    code, out = run(sb, repo, "install")
    assert "taken" not in out and "fk has no parts yet" in out, out
    code, out = run(sb, repo, "nope")
    assert code == 1 and "unknown command 'nope'" in out, out


def test_picker_runs_a_subcommand(sb):
    repo = copy(sb)
    t = Term([repo + "/bin/fk"], sb.env, cols=100, rows=20, cwd=sb.home)
    t.wait_for("says hello")
    t.settle()
    assert "k-work" in t.text() and "k-tk" not in t.text(), t.text()
    for _ in range(4):
        if "fk hello" in t.cursor_line():
            break
        t.key("up")
    assert "fk hello" in t.cursor_line(), t.text()
    t.key("enter")
    t.wait_for("hello from the layer:")
    t.wait_exit()
