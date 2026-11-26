"""A first run with no layers: ./install.sh offers the layers unikit knows (nothing ticked), adds
the ticked ones and goes on with their parts; skipped, it's offered again next run. uk layer add
takes those names. A scratch copy of the repo with no layers; `git clone` of a known layer's
GitHub address is served from a local repo (no network)."""
import os
import shutil
import subprocess

from fixture import REPO
from term import Term

GIT = ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "init.defaultBranch=main"]
REAL_GIT = shutil.which("git")


def setup(sb):
    repo = sb.root + "/repo"
    shutil.copytree(REPO, repo, ignore=shutil.ignore_patterns(".git", "layers.lock", "tests", "tasks", "layers", "*.zip"))
    src = sb.root + "/src/bluetools"                       # stands in for github.com/bluestero/bluetools
    os.makedirs(src)
    with open(src + "/components.sh", "w") as f:
        f.write('COMPONENTS+=(demo-part)\ngroup_demo_part() { echo Demo; }\n'
                'label_demo_part() { echo Demo; }; title_demo_part() { echo "a demo part"; }\n'
                'detail_demo_part() { echo nothing; }; state_demo_part() { STATE=missing NOTE=""; }\n'
                'install_demo_part() { :; }; uninstall_demo_part() { :; }\n')
    with open(src + "/README.md", "w") as f:
        f.write("# bluetools\n\nA stand-in.\n")
    subprocess.run(["git", "init", "-q", src], check=True, env=sb.env)
    subprocess.run(GIT + ["-C", src, "add", "-A"], check=True, env=sb.env)
    subprocess.run(GIT + ["-C", src, "commit", "-qm", "first"], check=True, env=sb.env)
    sb.fake("git", f'''[ "$1" = clone ] && [ "$3" = https://github.com/bluestero/bluetools.git ] && exec {REAL_GIT} clone -q "{src}" "$4"
exec {REAL_GIT} "$@"''')
    return repo


def test_uk_layer_add_takes_a_known_name(sb):
    repo = setup(sb)
    p = subprocess.run([repo + "/bin/uk", "layer", "add", "--yes", "--no-setup", "bluetools"], env=sb.env,
                       cwd=sb.home, capture_output=True, text=True, stdin=subprocess.DEVNULL, timeout=60)
    out = p.stdout + p.stderr
    assert p.returncode == 0 and os.path.isfile(repo + "/layers/bluetools/components.sh"), out
    assert any("clone -q https://github.com/bluestero/bluetools.git" in c for c in sb.calls("git")), sb.calls("git")


def test_first_run_offers_the_layers_and_goes_on_with_the_ticked_ones(sb):
    repo = setup(sb)
    t = Term([repo + "/install.sh", "--plain"], sb.env, cols=140, rows=40, cwd=sb.home)
    t.wait_for("Add which layers?")
    assert "bluetools" in t.text() and "bluefeels" in t.text() and "uk layer add bluetools" in t.text(), t.text()
    t.key("tab", "enter")                                  # tick bluetools (the first row)
    t.wait_for("Trust bluetools and add it?")
    t.key("down", "enter")                                 # Yes (No is on top)
    t.wait_for("│ Demo │")                                 # the installer again, with its parts' tab
    t.key("esc")
    t.wait_exit()
    assert os.path.isdir(repo + "/layers/bluetools")


def test_skipped_it_is_offered_again(sb):
    repo = setup(sb)
    for _ in range(2):
        t = Term([repo + "/install.sh", "--plain"], sb.env, cols=140, rows=40, cwd=sb.home)
        t.wait_for("Add which layers?")
        t.key("q")                                         # none for now
        t.wait_for("Recommended")                          # unikit's own parts still offered
        t.key("esc")
        t.wait_exit()
    assert not os.path.exists(repo + "/layers") or not os.listdir(repo + "/layers")
