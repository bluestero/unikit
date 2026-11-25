"""What keeps layers from stepping on each other, in a scratch copy of the repo with the test's
own layers: a part name that's taken leaves that layer's parts out; two layers' parts that
change the same file ask first (skip by default, --yes skips too); unikit's commands come
first on PATH; a layer's requires file names the layers it needs."""
import os
import shutil
import subprocess

from fixture import REPO
from term import Term


def copy(sb):
    dst = sb.root + "/repo"
    shutil.copytree(REPO, dst, ignore=shutil.ignore_patterns(".git", "layers.lock", "tests", "tasks", "layers", "*.zip"))
    return dst


def layer(repo, name, body, **files):
    d = f"{repo}/layers/{name}"
    os.makedirs(d, exist_ok=True)
    with open(d + "/components.sh", "w") as f:
        f.write(body)
    for k, v in files.items():
        os.makedirs(os.path.dirname(f"{d}/{k}"), exist_ok=True)
        with open(f"{d}/{k}", "w") as f:
            f.write(v)
    return d


def part(pid, file, extra=""):
    """A part that writes <file> with its name in it; set up when the file says so."""
    fn = pid.replace("-", "_")
    return (f'COMPONENTS+=({pid})\ngroup_{fn}() {{ echo Demo; }}; label_{fn}() {{ echo {pid}; }}\n'
            f'title_{fn}() {{ echo "writes {file}"; }}; detail_{fn}() {{ echo {file}; }}\n'
            f'state_{fn}() {{ NOTE=""; if grep -qx {pid} "{file}" 2>/dev/null; then STATE=installed; else STATE=missing; fi; }}\n'
            f'install_{fn}() {{ dry || {{ echo {pid} >"{file}"; ok "wrote it"; }}; }}; uninstall_{fn}() {{ rm -f "{file}"; }}\n'
            f'touches_{fn}() {{ echo "{file}"; }}\n{extra}')


def run(sb, repo, *args):
    p = subprocess.run([repo + "/" + args[0], *args[1:]], env=sb.env, cwd=sb.home, capture_output=True,
                       text=True, stdin=subprocess.DEVNULL, timeout=60)
    return p.returncode, p.stdout + p.stderr


def test_a_taken_part_name_leaves_the_layers_parts_out(sb):
    repo = copy(sb)
    layer(repo, "sneaky", part("fzf", sb.home + "/x") + part("sneaky-own", sb.home + "/y"))
    _, out = run(sb, repo, "install.sh", "ls")
    assert "layer sneaky: its parts are left out: fzf is taken" in out, out
    assert "sneaky-own" not in out, out
    code, out = run(sb, repo, "bin/uk", "doctor")
    assert code == 1 and "its parts are left out: fzf is taken" in out, out


def test_the_same_file_asks_and_skips_by_default(sb):
    repo = copy(sb)
    f = sb.home + "/shared.conf"
    layer(repo, "one", part("one-conf", f))
    layer(repo, "two", part("two-conf", f))
    run(sb, repo, "install.sh", "--yes", "one-conf")
    assert open(f).read().strip() == "one-conf"
    _, out = run(sb, repo, "install.sh", "--yes", "two-conf")      # --yes never replaces
    assert "is set up by one-conf (one)" in out and "one-conf keeps it" in out, out
    assert open(f).read().strip() == "one-conf"
    t = Term([repo + "/install.sh", "--plain", "two-conf"], sb.env, cols=130, rows=30, cwd=sb.home)
    t.wait_for("would change it too")
    assert "Skip it" in t.text() and "Replace one-conf's" in t.text() and "Add both" not in t.text(), t.text()
    t.key("enter")                                                     # the default: skip
    t.wait_exit(timeout=20)
    assert open(f).read().strip() == "one-conf"


def test_replace_and_add_both(sb):
    repo = copy(sb)
    f = sb.home + "/shared.conf"
    layer(repo, "one", part("one-conf", f))
    layer(repo, "two", part("two-conf", f, extra=f'addboth_two_conf() {{ echo two-extra >"{f}.two"; ok "beside it"; }}\n'))
    run(sb, repo, "install.sh", "--yes", "one-conf")
    t = Term([repo + "/install.sh", "--plain", "two-conf"], sb.env, cols=130, rows=30, cwd=sb.home)
    t.wait_for("Add both")
    t.key("down", "down", "enter")
    t.wait_exit(timeout=20)
    assert open(f).read().strip() == "one-conf" and os.path.exists(f + ".two"), t.text()
    t = Term([repo + "/install.sh", "--plain", "two-conf"], sb.env, cols=130, rows=30, cwd=sb.home)
    t.wait_for("Replace one-conf's")
    t.key("down", "enter")
    t.wait_exit(timeout=20)
    assert open(f).read().strip() == "two-conf", t.text()


def shared(pid, thing):
    """A part for one shared thing (like a GNOME extension two layers both bring): set up when it's
    there, whichever part made it; its uninstall leaves it while another layer's part has it."""
    fn = pid.replace("-", "_")
    return (f'COMPONENTS+=({pid})\ngroup_{fn}() {{ echo Demo; }}; label_{fn}() {{ echo {pid}; }}\n'
            f'title_{fn}() {{ echo "sets up {thing}"; }}; detail_{fn}() {{ echo {thing}; }}\n'
            f'touches_{fn}() {{ echo "{thing}"; }}\n'
            f'state_{fn}() {{ NOTE=""; if [[ -f "{thing}" ]]; then STATE=installed; else STATE=missing; fi; }}\n'
            f'install_{fn}() {{ [[ -f "{thing}" ]] && {{ ok "already set up"; return; }}; dry || {{ touch "{thing}"; ok "set up"; }}; }}\n'
            f'uninstall_{fn}() {{ shared_keep {pid} && return; '
            f'rm -f "{thing}"; ok "removed"; }}\n')


def test_one_thing_two_layers_bring_is_set_up_once_and_kept_while_one_wants_it(sb):
    repo = copy(sb)
    thing = sb.home + "/extension"
    layer(repo, "one", shared("one-ext", thing))
    layer(repo, "two", shared("two-ext", thing))
    run(sb, repo, "install.sh", "--yes", "one-ext")
    _, out = run(sb, repo, "install.sh", "--yes", "two-ext")           # set up already: no question
    assert "would change it too" not in out and "already set up" in out, out
    _, out = run(sb, repo, "uninstall.sh", "--yes", "one-ext")         # two's still has it: --yes keeps it
    assert "left as it is: two-ext (two) has it set up too" in out and os.path.exists(thing), out
    t = Term([repo + "/uninstall.sh", "--plain", "one-ext"], sb.env, cols=130, rows=30, cwd=sb.home)
    t.wait_for("Go ahead?")
    t.key("enter")
    t.wait_for("Remove it anyway?")
    t.key("enter")                                                     # the default: no
    t.wait_exit(timeout=20)
    assert os.path.exists(thing), t.text()


def test_unikits_commands_come_first_on_path(sb):
    repo = copy(sb)
    d = layer(repo, "shadow", "")
    os.makedirs(d + "/bin")
    for name in ("tk", "shadow-cmd"):
        with open(f"{d}/bin/{name}", "w") as f:
            f.write("#!/bin/sh\necho shadow\n")
        os.chmod(f"{d}/bin/{name}", 0o755)
    out = subprocess.run(["bash", "-c", f'. "{repo}/shell/init.sh" >/dev/null 2>&1; type -P tk; type -P shadow-cmd'],
                         env=sb.env, cwd=sb.home, capture_output=True, text=True, timeout=60).stdout.split()
    assert out == [repo + "/bin/tk", d + "/bin/shadow-cmd"], out


def test_requires_names_a_missing_layer(sb):
    repo = copy(sb)
    sb.add_path(repo + "/bin")
    layer(repo, "needy", "", requires="# what it builds on\nbase-team\n")
    code, out = run(sb, repo, "bin/uk", "doctor")
    assert code == 1 and "needs the base-team layer, which isn't here" in out, out
    layer(repo, "base-team", "")
    code, out = run(sb, repo, "bin/uk", "doctor")
    assert "needs the base-team layer" not in out, out


def test_a_layer_that_does_not_load_is_left_out(sb):
    repo = copy(sb)
    layer(repo, "broken", part("broken-own", sb.home + "/x") + "if then\n")
    layer(repo, "fine", part("fine-own", sb.home + "/y"))
    code, out = run(sb, repo, "install.sh", "ls")
    assert code == 0, out
    assert "layer broken: its parts are left out: its components.sh doesn't load" in out, out
    assert "broken-own" not in out and "fine-own" in out, out
    code, out = run(sb, repo, "bin/uk", "doctor")
    assert code == 1 and "its components.sh doesn't load" in out, out


def test_a_status_check_that_fails_never_stops_the_installer(sb):
    repo = copy(sb)
    layer(repo, "shaky", 'COMPONENTS+=(shaky-own)\ngroup_shaky_own() { echo Demo; }; label_shaky_own() { echo shaky; }\n'
          'title_shaky_own() { echo shaky; }; detail_shaky_own() { echo shaky; }\n'
          'state_shaky_own() { NOTE=$nope; no-such-command || return; STATE=installed; }\n'
          'install_shaky_own() { :; }; uninstall_shaky_own() { :; }\n')
    layer(repo, "fine", part("fine-own", sb.home + "/y"))
    code, out = run(sb, repo, "install.sh", "ls")
    assert code == 0, out
    assert "fine-own" in out, out
    assert "its status check failed" in out, out


def test_a_second_run_waits_for_the_first(sb):
    repo = copy(sb)
    layer(repo, "one", part("one-conf", sb.home + "/one.conf"))
    state = sb.home + "/.local/state/unikit"
    os.makedirs(state, exist_ok=True)
    holder = subprocess.Popen(["bash", "-c", "sleep 2; :", "install.sh"])
    with open(state + "/run.lock", "w") as f:
        f.write(f"{holder.pid}\t./install.sh bash\n")
    code, out = run(sb, repo, "install.sh", "--yes", "one-conf")
    holder.wait()
    assert code == 0, out
    assert "Waiting for the other unikit run to finish: ./install.sh bash" in out, out
    assert open(sb.home + "/one.conf").read().strip() == "one-conf", out
    assert not os.path.exists(state + "/run.lock"), out


def test_a_lock_left_by_a_gone_run_is_cleared(sb):
    repo = copy(sb)
    layer(repo, "one", part("one-conf", sb.home + "/one.conf"))
    state = sb.home + "/.local/state/unikit"
    os.makedirs(state, exist_ok=True)
    with open(state + "/run.lock", "w") as f:
        f.write("999999\t./install.sh bash\n")
    code, out = run(sb, repo, "install.sh", "--yes", "one-conf")
    assert code == 0 and "Waiting" not in out, out
    assert open(sb.home + "/one.conf").read().strip() == "one-conf", out
