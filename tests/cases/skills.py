"""The Claude skills and plugins picker (install.sh claude-skill), in a scratch copy of the repo
whose one layer brings two skills (alpha, beta) and a plugin (gamma, through a fake claude), with
1, 2 or 7 fake Claude profiles: ticks start on what's in every profile, ◐ for some; then the
profiles; alt-g picks exact profile/skill pairs; removing something asks in the list first,
default No."""
import os
import re
import shutil
import subprocess

from fixture import REPO
from term import Term


def setup(sb, profiles):
    """profiles: names; 'default' is ~/.claude, the rest ~/.claude-profiles/<name>."""
    repo = sb.root + "/repo"
    shutil.copytree(REPO, repo, ignore=shutil.ignore_patterns(".git", "layers.lock", "tests", "tasks", "layers", "*.zip"))
    for s in ("alpha", "beta"):
        os.makedirs(f"{repo}/layers/team/claude/skills/{s}")
        with open(f"{repo}/layers/team/claude/skills/{s}/SKILL.md", "w") as f:
            f.write(f"---\nname: {s}\ndescription: the {s} skill\n---\n")
    with open(f"{repo}/layers/team/claude/plugins", "w") as f:
        f.write("# plugin@marketplace|GitHub repo|what it gives\ngamma@gmkt|owner/gamma|the gamma plugin\n")
    # claude plugin ...: keeps the two files Claude Code keeps, in the profile it runs for
    sb.fake("claude", '''d="$CLAUDE_CONFIG_DIR/plugins"; mkdir -p "$d"
case "$*" in
  "plugin marketplace add "*) echo '{"gmkt": {}}' >"$d/known_marketplaces.json" ;;
  "plugin marketplace remove "*) echo '{}' >"$d/known_marketplaces.json" ;;
  "plugin install "*) echo "{\\"$3\\": []}" >"$d/installed_plugins.json" ;;
  "plugin uninstall "*) echo '{}' >"$d/installed_plugins.json" ;;
esac''')
    for p in profiles:
        os.makedirs(prof(sb, p), exist_ok=True)
    return repo


def prof(sb, p):
    return sb.home + ("/.claude" if p == "default" else "/.claude-profiles/" + p)


def link(sb, repo, p, skill):
    os.makedirs(prof(sb, p) + "/skills", exist_ok=True)
    os.symlink(f"{repo}/layers/team/claude/skills/{skill}", f"{prof(sb, p)}/skills/{skill}")


def has(sb, p, skill):
    return os.path.islink(f"{prof(sb, p)}/skills/{skill}")


def has_plugin(sb, p):
    return "gamma@gmkt" in (sb.read(prof(sb, p) + "/plugins/installed_plugins.json") or "")


def start(sb, repo):
    t = Term([repo + "/install.sh", "--plain", "claude-skill"], sb.env, cols=150, rows=34, cwd=sb.home)
    t.wait_for("PROFILES", timeout=20)
    t.settle()
    return t


def row(t):
    """The cursor's row in the list, without the preview pane beside it."""
    return next((p for p in t.cursor_line().split("│") if "▶" in p), "")


def to(t, *needles):
    """Move the cursor down to the row with all the needles (the rows are few)."""
    for _ in range(30):
        if all(n in row(t) for n in needles):
            return
        t.key("down")
        t.settle(quiet=0.15)
    assert all(n in row(t) for n in needles), t.text()


def done(t):
    assert t.wait_exit(timeout=20) == 0, t.text()


def test_one_profile_picks_and_applies_without_asking_for_profiles(sb):
    repo = setup(sb, ["default"])
    t = start(sb, repo)
    assert "alpha" in t.text() and "[✓]" not in t.text(), t.text()
    to(t, "alpha")
    t.key("tab")
    t.wait(lambda t: "[✓]" in t.cursor_line(), what="alpha ticked")
    t.key("enter")
    done(t)
    assert has(sb, "default", "alpha") and not has(sb, "default", "beta")


def test_two_profiles_partial_starts_unticked_then_the_profiles(sb):
    repo = setup(sb, ["default", "work"])
    link(sb, repo, "work", "alpha")
    t = start(sb, repo)
    row = next(l for l in t.text().splitlines() if "alpha" in l and "team" in l)   # its row, not the preview's title
    assert "◐" in row and "work" in row and "[✓]" not in row, t.text()
    to(t, "alpha")
    t.key("ctrl-p")                                               # the pane, closed at first
    t.wait_for("✓ work")                                          # the pane: per profile
    t.key("tab", "enter")
    t.wait(lambda t: (t.line_with(".claude-profiles/work") or "").find("[✓]") >= 0,
           what="the profiles: work has alpha, so it's ticked")
    assert "[✓]" not in t.line_with("~/.claude "), t.text()
    to(t, "~/.claude ")
    t.key("tab", "enter")
    done(t)
    assert has(sb, "default", "alpha") and has(sb, "work", "alpha") and not has(sb, "default", "beta")


def test_ctrl_p_opens_the_pane_right_then_below_then_closes_it(sb):
    repo = setup(sb, ["default", "work"])
    t = start(sb, repo)
    assert "the alpha skill" not in t.text(), t.text()              # closed at first
    t.key("ctrl-p")
    beside = lambda t: (t.line_with("beta") or "").split("beta", 1)[-1].count("│") >= 3   # the pane's two sides on beta's row
    t.wait(beside, what="the pane on the right, beside the rows")
    t.key("ctrl-p")
    t.wait(lambda t: not beside(t) and t.text().find("– default") > t.text().find("beta"),
           what="the pane below the rows")
    t.key("ctrl-p")
    t.wait_gone("the alpha skill")
    t.key("esc")
    done(t)


def test_two_profiles_nothing_installed_ticks_no_profile(sb):
    repo = setup(sb, ["default", "work"])
    t = start(sb, repo)
    to(t, "beta")
    t.key("tab", "enter")
    t.wait(lambda t: t.line_with(".claude-profiles/work") is not None, what="the profiles")
    t.settle()
    assert "[✓]" not in t.text(), t.text()
    t.key("enter")                                                # no profile: nothing linked
    done(t)
    assert not has(sb, "default", "beta") and not has(sb, "work", "beta")


def test_unticking_an_installed_skill_asks_default_no(sb):
    repo = setup(sb, ["default", "work"])
    link(sb, repo, "default", "beta")
    link(sb, repo, "work", "beta")
    t = start(sb, repo)
    assert "[✓]" in t.line_with("beta"), t.text()                  # in every profile: ticked
    to(t, "beta")
    t.key("tab", "enter")
    t.wait_for("Remove beta (default), beta (work)?")
    t.key("enter")                                                # the default: no, back to the list
    t.wait_for("Nothing removed")
    assert has(sb, "default", "beta") and has(sb, "work", "beta")
    t.key("enter")
    t.wait_for("Remove beta (default), beta (work)?")
    t.key("y")
    done(t)
    assert not has(sb, "default", "beta") and not has(sb, "work", "beta")


def test_seven_profiles_count_and_exact_pairs(sb):
    names = ["default"] + [f"profile{i}" for i in range(1, 7)]
    repo = setup(sb, names)
    for p in ("profile1", "profile2", "profile3"):
        link(sb, repo, p, "alpha")
    t = start(sb, repo)
    assert re.search(r"alpha\s+skill\s+team\s+◐ 3/7", t.text()), t.text()   # too many names: a count
    t.key("alt-g")                                                # a row per profile and skill
    t.wait_for("NOW")
    to(t, "profile1 ", "alpha")
    assert "[✓]" in row(t), t.text()                              # profile1 has alpha: ticked
    t.key("tab")                                                  # profile1 loses alpha
    t.wait(lambda t: "[✓]" not in row(t), what="unticked")
    t.key("down")
    t.settle(quiet=0.15)
    assert "profile1" in row(t) and "beta" in row(t), t.text()
    t.key("tab", "enter")                                         # profile1 gains beta
    t.wait_for("Remove alpha (profile1)?")
    t.key("y")
    done(t)
    assert not has(sb, "profile1", "alpha") and has(sb, "profile1", "beta")
    assert has(sb, "profile2", "alpha") and has(sb, "profile3", "alpha")
    assert not has(sb, "default", "alpha") and not has(sb, "profile4", "beta")


def test_skills_ls_names_each_skills_layer_and_profiles(sb):
    repo = setup(sb, ["default", "work"])
    link(sb, repo, "work", "alpha")
    p = subprocess.run([repo + "/bin/uk", "skills", "ls"], env=sb.env, cwd=sb.home, capture_output=True, text=True,
                       timeout=30, stdin=subprocess.DEVNULL)
    lines = [l.split() for l in p.stdout.splitlines()]
    assert ["alpha", "skill", "team", "◐", "work"] in lines and ["beta", "skill", "team", "–", "none"] in lines, p.stdout + p.stderr
    assert ["gamma", "plugin", "team", "–", "none"] in lines and not any(l and l[0] == "#" for l in lines), p.stdout
    p = subprocess.run([repo + "/bin/uk", "skills", "alpha"], env=sb.env, cwd=sb.home, capture_output=True, text=True,
                       timeout=30, stdin=subprocess.DEVNULL)
    lines = [l.split() for l in p.stdout.splitlines()]
    assert ["about", "the", "alpha", "skill"] in lines and ["work", "✓", "has", "it"] in lines, p.stdout + p.stderr
    assert ["default", "–", "not", "set", "up"] in lines, p.stdout
    p = subprocess.run([repo + "/bin/uk", "skills", "gamma"], env=sb.env, cwd=sb.home, capture_output=True, text=True,
                       timeout=30, stdin=subprocess.DEVNULL)
    lines = [l.split() for l in p.stdout.splitlines()]
    assert ["type", "plugin"] in lines and ["from", "github.com/owner/gamma"] in lines, p.stdout + p.stderr


def test_a_plugin_installs_in_the_picked_profile_and_goes_with_its_source(sb):
    repo = setup(sb, ["default"])
    t = start(sb, repo)
    row_ = next(l for l in t.text().splitlines() if "gamma" in l)
    assert "plugin" in row_ and "team" in row_ and "[✓]" not in row_, t.text()
    to(t, "gamma")
    t.key("tab", "enter")
    done(t)
    assert has_plugin(sb, "default"), sb.calls("claude")
    assert sb.calls("claude") == ["claude plugin marketplace add owner/gamma", "claude plugin install gamma@gmkt"]
    t = start(sb, repo)                                           # again: ticked, untick it
    assert "[✓]" in t.line_with("gamma"), t.text()
    to(t, "gamma")
    t.key("tab", "enter")
    t.wait_for("Remove gamma (default)?")
    t.key("y")
    done(t)
    assert not has_plugin(sb, "default")
    assert sb.calls("claude")[2:] == ["claude plugin uninstall gamma@gmkt", "claude plugin marketplace remove gmkt"]


def test_a_plugin_source_the_user_added_stays(sb):
    repo = setup(sb, ["default"])
    sb.write(prof(sb, "default") + "/plugins/known_marketplaces.json", '{"gmkt": {}}')
    sb.write(prof(sb, "default") + "/plugins/installed_plugins.json", '{"gamma@gmkt": []}')
    t = start(sb, repo)
    to(t, "gamma")
    t.key("tab", "enter")
    t.wait_for("Remove gamma (default)?")
    t.key("y")
    done(t)
    assert sb.calls("claude") == ["claude plugin uninstall gamma@gmkt"]
