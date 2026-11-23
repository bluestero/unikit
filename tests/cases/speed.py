"""Speed (tasks/11): unikit's own pickers and commands against their budgets (tests/lib/budget.py).
Run by name only (tests/run.sh speed); a layer's speed_<name> files time its tools the same way."""
import os

from budget import CALLBACK, OPEN, check, commands, opened, record, report  # noqa: F401  (report: the runner calls it)
from fixture import REPO
from worlds import FK, FK_LAYER


def test_fk_configs(sb):
    if not os.path.exists(FK_LAYER):
        return
    vitals = "Vitals@CoreCoding.com"
    os.makedirs(sb.path(f"~/.local/share/gnome-shell/extensions/{vitals}"))
    sb.write(sb.fix + "/enabled-extensions", f"['{vitals}']\n")
    t, secs = opened(sb, lambda sb: ([FK, "configs"], "Vitals", None))
    rows = [("fk configs · open", record("fk configs · open", secs, OPEN), OPEN)]
    t.key("Vitals")                                      # bluefeels' other presets come first
    t.settle()
    enter = [t.timed_key("enter", lambda t: "Keep my settings" in t.text())]
    rows.append(("fk configs · enter → choices", record("fk configs · enter → choices", enter, CALLBACK), CALLBACK))
    t.close()
    check(*rows)


# ------------------------------------------------------------- commands
def test_commands(sb):
    cmds = [("tk ls", [f"{REPO}/bin/tk", "ls"])]
    if os.path.exists(FK):
        cmds.append(("fk help", [FK, "help"]))
    commands(sb, cmds)
