"""Speed budgets (tasks/11) for the speed case files (unikit's and the layers'): time a key or a
command against a budget, a table at the end. Each case file sets report = budget.report.

Budgets: a key that moves or filters < 50 ms; a key that runs a callback < 150 ms; a picker
open < 300 ms; a command printing its list < 300 ms. Each number is the median of a few tries,
in a sandbox with fakes, so kubectl / aws time isn't in it.
"""
import statistics
import subprocess
import time

from term import Term

MOVE, CALLBACK, OPEN, COMMAND = 50, 150, 300, 300
RESULTS = []   # (what, ms, budget)


def record(what, secs, budget):
    ms = round(statistics.median(secs) * 1000)
    RESULTS.append((what, ms, budget))
    return ms


def check(*rows):
    over = [f"{w}: {ms} ms (budget {b})" for w, ms, b in rows if ms > b]
    assert not over, "over budget: " + " · ".join(over)


def report():
    if not RESULTS:
        return
    w = max(len(r[0]) for r in RESULTS)
    print(f"\n  {'what'.ljust(w)}   {'ms':>5}   budget")
    for what, ms, budget in RESULTS:
        mark = "✗" if ms > budget else "✓"
        print(f"  {what.ljust(w)}   {ms:>5}   {budget:>6}  {mark}")
    RESULTS.clear()


def opened(sb, world, tries=3):
    cmd, ready, cwd = world(sb)
    secs = []
    for _ in range(tries):
        t0 = time.monotonic()
        t = Term(cmd, sb.env, cwd=cwd)
        t.wait_for(ready)
        secs.append(time.monotonic() - t0)
        t.settle()
        if _ < tries - 1:
            t.close()
    return t, secs


def to_row(t, text):
    """Put the pointer on the row showing text."""
    for k in ["up"] * 5 + ["down"] * 10:
        if text in (t.cursor_line() or ""):
            return
        t.key(k, gap=0.1)
    raise AssertionError(f"no row with {text!r}")


def picker(sb, world, name, question_key=None, question=None, row=None, move=("down", "up", "down", "up")):
    t, secs = opened(sb, world)
    rows = [(f"{name} · open", record(f"{name} · open", secs, OPEN), OPEN)]
    what = f"{name} · {' '.join(dict.fromkeys(move))}"
    secs = [t.timed_key(k) for k in move]
    rows.append((what, record(what, secs, MOVE), MOVE))
    t.settle(0.2)
    first = [t.timed_key("a")]
    rows.append((f"{name} · first filter key", record(f"{name} · first filter key", first, MOVE), MOVE))
    t.key("bs")
    t.settle(0.2)
    if question_key:
        if row:
            to_row(t, row)
            t.settle(0.2)
        what = f"{name} · {question_key} → question"
        secs = [t.timed_key(question_key, lambda t: question in t.flat())]
        rows.append((what, record(what, secs, CALLBACK), CALLBACK))
    t.close()
    check(*rows)


def commands(sb, cmds):
    """Start-up time of each (name, argv), 3 tries each, against COMMAND."""
    rows = []
    for name, cmd in cmds:
        secs = []
        for _ in range(3):
            t0 = time.monotonic()
            subprocess.run(cmd, env=sb.env, cwd=sb.home, stdin=subprocess.DEVNULL,
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30)
            secs.append(time.monotonic() - t0)
        rows.append((name, record(name, secs, COMMAND), COMMAND))
    check(*rows)
