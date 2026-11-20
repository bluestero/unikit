"""The Claude skills picker (install.sh claude-skill), in a scratch copy of the repo whose one
layer brings two skills (alpha, beta) next to unikit's own, with 1, 2 or 7 fake Claude profiles:
ticks start on what's in every profile, ◐ for some; then the profiles; alt-g picks exact
profile/skill pairs; removing something asks in the list first, default No."""
import os
import re
import shutil

from fixture import REPO
from term import Term


def setup(sb, profiles):
    """profiles: names; 'default' is ~/.claude, the rest ~/.claude-profiles/<name>."""
    repo = sb.root + "/repo"
    shutil.copytree(REPO, repo, ignore=shutil.ignore_patterns(".git", "tests", "tasks", "layers", "*.zip"))
    for s in ("alpha", "beta"):
        os.makedirs(f"{repo}/layers/team/claude/skills/{s}")
        with open(f"{repo}/layers/team/claude/skills/{s}/SKILL.md", "w") as f:
            f.write(f"---\nname: {s}\ndescription: the {s} skill\n---\n")
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


def start(sb, repo):
    t = Term([repo + "/install.sh", "--plain", "claude-skill"], sb.env, cols=150, rows=34, cwd=sb.home)
    t.wait_for("SKILL", timeout=20)
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
    assert "work-toolkit" in t.text() and "alpha" in t.text() and "[✓]" not in t.text(), t.text()
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
    row = t.line_with("alpha")
    assert "◐" in row and "work" in row and "[✓]" not in row, t.text()
    to(t, "alpha")
    t.wait_for("✓ work")                                          # the preview: per profile
    t.key("tab", "enter")
    t.wait(lambda t: (t.line_with(".claude-profiles/work") or "").find("[✓]") >= 0,
           what="the profiles: work has alpha, so it's ticked")
    assert "[✓]" not in t.line_with("~/.claude "), t.text()
    to(t, "~/.claude ")
    t.key("tab", "enter")
    done(t)
    assert has(sb, "default", "alpha") and has(sb, "work", "alpha") and not has(sb, "default", "beta")


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
    t.wait_for("Remove 2 skill link(s)?")
    t.key("enter")                                                # the default: no, back to the list
    t.wait_for("Nothing removed")
    assert has(sb, "default", "beta") and has(sb, "work", "beta")
    t.key("enter")
    t.wait_for("Remove 2 skill link(s)?")
    t.key("y")
    done(t)
    assert not has(sb, "default", "beta") and not has(sb, "work", "beta")


def test_seven_profiles_count_and_exact_pairs(sb):
    names = ["default"] + [f"profile{i}" for i in range(1, 7)]
    repo = setup(sb, names)
    for p in ("profile1", "profile2", "profile3"):
        link(sb, repo, p, "alpha")
    t = start(sb, repo)
    assert re.search(r"alpha\s+team\s+◐ 3/7", t.text()), t.text()   # too many names: a count
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
    t.wait_for("Remove 1 skill link(s)? alpha (profile1)")
    t.key("y")
    done(t)
    assert not has(sb, "profile1", "alpha") and has(sb, "profile1", "beta")
    assert has(sb, "profile2", "alpha") and has(sb, "profile3", "alpha")
    assert not has(sb, "default", "alpha") and not has(sb, "profile4", "beta")
