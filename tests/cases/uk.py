"""uk, unikit's base command, in a scratch copy of the repo with no layers but the test's own:
help and version; uk layer add / rm without a terminal; the uk layers list (about card, add,
remove); uk doctor on a well formed layer and a broken one; tk layer is gone; the installers'
LAYER column; the long command names never take a name another program has; tk and fk are
siblings (the same words, an empty kit says so, a layer's <kit>/<name>)."""
import os
import re
import shutil
import subprocess

from fixture import REPO
from term import Term

GIT = ["git", "-c", "user.name=t", "-c", "user.email=t@t", "-c", "init.defaultBranch=main"]


def copy(sb):
    dst = sb.root + "/repo"
    shutil.copytree(REPO, dst, ignore=shutil.ignore_patterns(".git", "layers.lock", "tests", "tasks", "layers", "*.zip"))
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
    assert code == 1 and "no terminal to ask in" in out and "commands: hello-unix-acme-toolkit" in out, out
    assert not os.listdir(repo + "/layers"), "nothing left of it"
    code, out = run(sb, repo, "uk", "layer", "add", "--yes", src)
    assert code == 0 and "layer acme added" in out and "Later: tk install --layer=acme" in out, out
    assert open(repo + "/layers.lock").read().startswith("acme\t")
    assert os.path.isfile(repo + "/layers/acme/tools")
    code, out = run(sb, repo, "uk", "layers")
    assert "acme" in out and src in out, out
    code, out = run(sb, repo, "uk", "layer", "rm", "acme")
    assert "Kept." in out and os.path.isdir(repo + "/layers/acme"), "no terminal to confirm in: nothing removed"
    code, out = run(sb, repo, "uk", "layer", "add", "--yes", src)
    assert code == 1 and "already there" in out, out


def test_tk_layer_is_gone(sb):
    repo = copy(sb)
    for word in ("layer", "status", "version", "update"):            # uk's words now
        code, out = run(sb, repo, "tk", word)
        assert code == 1 and f"unknown command '{word}'" in out, out
    code, out = run(sb, repo, "tk", "help")
    assert "tk layer" not in out and "tk status" not in out, out


def test_doctor_passes_a_good_layer_and_names_a_broken_ones_faults(sb):
    repo = copy(sb)
    sb.add_path(repo + "/bin")
    subprocess.run(GIT + ["clone", "-q", source(sb, "good", part=True), repo + "/layers/good"], check=True, env=sb.env)
    code, out = run(sb, repo, "uk", "doctor")
    assert code == 1 and "good" in out and "has no pin" in out, out    # cloned by hand: never trusted
    head = subprocess.run(["git", "-C", repo + "/layers/good", "rev-parse", "HEAD"], capture_output=True, text=True).stdout
    with open(repo + "/layers.lock", "w") as f:
        f.write("good\t" + head)
    code, out = run(sb, repo, "uk", "doctor")
    assert code == 0 and "good" in out and "!" not in out, out
    bad = repo + "/layers/bad"
    os.makedirs(bad + "/bin")
    with open(bad + "/kit", "w") as f:
        f.write("gk\n")
    os.makedirs(bad + "/fk")
    for name in ("../fk/install", "tk", "hello-good", "notrun"):
        with open(bad + "/bin/" + name, "w") as f:
            f.write("#!/bin/sh\n")
        if name != "notrun":
            os.chmod(bad + "/bin/" + name, 0o755)
    with open(bad + "/tools", "w") as f:
        f.write("nowhere|Work|a command it doesn't have|\nhalf|Work\n")
    code, out = run(sb, repo, "uk", "doctor")
    assert code == 1, out
    for fault in ("kit file says 'gk'", "fk/install never runs", "bin/tk never runs: unikit's tk comes first",
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
    t.wait_for("Trust acme?")
    assert "commands: hello-unix-acme-toolkit" in t.text() and "first" in t.text(), t.text()
    t.key("enter")                                                # the default: no
    t.wait_for("Not added")
    assert sorted(os.listdir(repo + "/layers")) == ["look"], os.listdir(repo + "/layers")
    t.key("alt-a")
    t.wait_for("git URL?")
    t.key(src, "enter")
    t.wait_for("Trust acme?")
    t.key("y")
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
    assert "acme" not in open(repo + "/layers.lock").read(), "its pin goes with it"
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


def test_layer_check_a_folder_before_pushing_it(sb):
    repo = copy(sb)
    d = sb.root + "/mine"
    os.makedirs(d + "/bin")
    with open(d + "/bin/tk", "w") as f:
        f.write("#!/bin/sh\n")
    os.chmod(d + "/bin/tk", 0o755)
    with open(d + "/components.sh", "w") as f:
        f.write("COMPONENTS+=(fzf mine-part)\n")
    code, out = run(sb, repo, "uk", "layer", "check", d)
    assert code == 1, out
    for fault in ("bin/tk never runs: unikit's tk comes first", "its part names are taken: fzf (unikit)"):
        assert fault in out, (fault, out)
    os.remove(d + "/bin/tk")
    with open(d + "/components.sh", "w") as f:
        f.write("COMPONENTS+=(mine-part)\n")
    code, out = run(sb, repo, "uk", "layer", "check", d)
    assert code == 0 and "mine" in out, out


def test_the_layer_template_is_a_working_layer(sb):
    repo = copy(sb)
    code, out = run(sb, repo, "uk", "layer", "check", repo + "/docs/layer-template")
    assert code == 0 and "!" not in out, out
    shutil.copytree(repo + "/docs/layer-template", repo + "/layers/example")
    code, out = run(sb, repo, "../install.sh", "--yes", "example-hello")
    assert code == 0 and os.path.realpath(sb.path("~/.local/bin/example-hello")) == repo + "/layers/example/bin/example-hello", out
    out = subprocess.run(["bash", "-c", f'. "{repo}/shell/init.sh" >/dev/null 2>&1; example-hello'],
                         env=sb.env, cwd=sb.home, capture_output=True, text=True, timeout=60).stdout
    assert out.strip() == "hello from the example layer: it works", out
    code, out = run(sb, repo, "uk", "doctor")
    assert "example" in out and "! " not in out.split("example", 1)[1].split("\n")[0], out


def test_the_kits_are_siblings(sb):
    repo = copy(sb)
    for kit in ("tk", "fk"):                                      # the same words in both
        code, out = run(sb, repo, kit, "help")
        assert code == 0 and all(f"{kit} {w}" in out for w in ("ls", "install", "uninstall", "doctor", "help")), out
    code, out = run(sb, repo, "fk", "help")
    assert "Nothing here yet. Add a layer: uk layers" in out, out
    for word in ("ls", "doctor"):
        code, out = run(sb, repo, "fk", word)
        assert code == 0 and "Nothing here yet" in out, out
    d = repo + "/layers/acme"                                    # a layer's subcommand: tk/<name>
    os.makedirs(d + "/tk")
    with open(d + "/tk/hello", "w") as f:
        f.write('#!/bin/sh\necho "hello $*"\n')
    os.chmod(d + "/tk/hello", 0o755)
    with open(d + "/tools", "w") as f:
        f.write("tk hello|Work|says hello|\n")
    code, out = run(sb, repo, "tk", "hello", "there")
    assert code == 0 and out.strip() == "hello there", out
    code, out = run(sb, repo, "tk", "help")
    assert re.search(r"tk hello\s+says hello$", out, re.M), "no layer column: " + out
    code, out = run(sb, repo, "tk", "ls")
    assert re.search(r"tk hello\s+says hello\s+acme\s+✓ ready", out), out
    code, out = run(sb, repo, "fk", "hello")
    assert code != 0 and "unknown command 'hello'" in out, "tk's subcommand isn't fk's"


def test_each_kits_doctor_runs_its_parts_own_checks(sb):
    repo = copy(sb)
    d = repo + "/layers/acme"
    os.makedirs(d)
    with open(d + "/kit", "w") as f:
        f.write("fk\n")
    with open(d + "/components.sh", "w") as f:
        f.write('''COMPONENTS+=(acme-look acme-off)
label_acme_look() { echo look; }; state_acme_look() { STATE=installed; }
doctor_acme_look() { echo "✓ colours"; echo "! the font is gone — fk install acme-look"; }
label_acme_off() { echo off; }; state_acme_off() { STATE=missing; }
doctor_acme_off() { echo "! never asked: not set up"; }
''')
    code, out = run(sb, repo, "fk", "doctor")
    assert code == 1 and re.search(r"acme-look\s+! the font is gone\s+→ fk install acme-look", out), out
    assert "1 other check passes" in out and "never asked" not in out, out
    assert re.search(r"fk\s+! 1 of 2 parts set up\s+→ fk install acme-off", out), out
    code, out = run(sb, repo, "tk", "doctor")
    assert "acme" not in out, "fk's parts stay out of tk doctor"


def test_each_kits_me_is_about_that_kit(sb):
    repo = copy(sb)
    d = repo + "/layers/acme"
    os.makedirs(d)
    with open(d + "/kit", "w") as f:
        f.write("fk\n")
    with open(d + "/tools", "w") as f:
        f.write("acme-look|Look|the look|no-such-program\n")
    with open(d + "/components.sh", "w") as f:
        f.write('''COMPONENTS+=(acme-look acme-off)
label_acme_look() { echo look; }; state_acme_look() { STATE=installed; }
label_acme_off() { echo off; }; state_acme_off() { STATE=missing; }
''')
    code, out = run(sb, repo, "fk", "me")
    assert code == 0 and re.search(r"layers\s+acme", out), out
    assert re.search(r"parts\s+1 of 2 set up · missing: acme-off", out), out
    assert re.search(r"needs\s+✗ no-such-program · ✓ fzf", out), "what's missing comes first: " + out
    assert re.search(r"lives in\s+" + re.escape(repo.replace(sb.home, "~", 1)), out), out
    code, out = run(sb, repo, "tk", "me")
    assert code == 0 and "acme" not in out and "no-such-program" not in out, "fk's layer stays out of tk me: " + out


def test_uk_status_shows_each_kit(sb):
    repo = copy(sb)
    code, out = run(sb, repo, "uk", "status")
    assert code == 0 and "folder" in out and re.search(r"\btk\s+\d+ of \d+ parts set up", out), out
    assert "fk " not in out, "a kit with no parts here has no line"
    assert re.search(r"version\s+\S+", out), out


def test_doctor_names_what_two_layers_both_define(sb):
    repo = copy(sb)
    sb.add_path(repo + "/bin")

    def write(path, text, mode=0o644):
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "w") as f:
            f.write(text)
        os.chmod(path, mode)

    for name in ("aone", "btwo"):
        d = f"{repo}/layers/{name}"
        write(d + "/components.sh", "shared_helper() { :; }\n")
        write(d + "/shell/init.sh", "alias gs='git status'\nexport SAME_SETTING=1\nPATH=/x:$PATH\n")
        write(d + "/claude/skills/same/SKILL.md", "---\nname: same\n---\n")
        write(d + "/tools", "same|Work|does a thing|\n")
        write(d + "/bin/same", "#!/bin/sh\n", 0o755)
    write(repo + "/layers/aone/components.sh", "shared_helper() { :; }\nlink_file() { :; }\n")
    write(repo + "/layers/aone/bin/aone-up", "#!/bin/sh\nsudo true\ncurl -s x\n", 0o755)
    code, out = run(sb, repo, "uk", "doctor")
    assert code == 1, out
    for said in ("link_file (unikit)", "shared_helper (aone)", "alias gs (aone)", "variable SAME_SETTING (aone)",
                 "skill same: aone has one too", "tools: same (tk) is aone's too",
                 "sudo: bin/aone-up", "network: bin/aone-up"):
        assert said in out, (said, out)
    assert "PATH (aone)" not in out, out
    code, out = run(sb, repo, "uk", "layer", "check", repo + "/layers/btwo")
    assert code == 1 and "shared_helper (aone)" in out and "skill same" in out, out


def test_doctor_in_a_sized_terminal_flags_no_variable_bash_sets_itself(sb):
    import fcntl
    import pty
    import struct
    import termios
    repo = copy(sb)
    sb.add_path(repo + "/bin")
    for name in ("aone", "btwo"):
        d = f"{repo}/layers/{name}/shell"
        os.makedirs(d)
        with open(d + "/init.sh", "w") as f:
            f.write(f"/bin/true\nexport {name.upper()}_SETTING=1\n")
    m, s = pty.openpty()
    fcntl.ioctl(s, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    p = subprocess.run([repo + "/bin/uk", "doctor"], env=sb.env, cwd=sb.home, stdin=s, stderr=s,
                       stdout=subprocess.PIPE, text=True, timeout=60)
    os.close(m), os.close(s)
    assert p.returncode == 0 and "COLUMNS" not in p.stdout and "LINES" not in p.stdout, p.stdout
