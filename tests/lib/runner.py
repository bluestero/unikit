"""Runs tests/cases/<name>.py: every test_* function, in file order, each in a fresh Sandbox.
A layer's own tests are in layers/<layer>/tests/cases/<name>.py: run the same way, by name.

A case module may define skip() -> reason (or None) to skip the whole file, e.g. when
the tool it covers isn't installed. A test gets the sandbox as its argument.
A failing test keeps its sandbox and shows the last screen. A module's report(), if
any, runs after its tests (speed prints its table there).
"""
import importlib.util
import os
import sys
import time
import traceback

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from fixture import REPO, Sandbox  # noqa: E402
from term import Term  # noqa: E402

CASES = os.path.join(REPO, "tests", "cases")
LAYERS = os.path.join(REPO, "layers")
# a layer's own helpers (layers/<layer>/tests/lib), after unikit's: name them after the layer
if os.path.isdir(LAYERS):
    for _d in sorted(os.listdir(LAYERS)):
        if os.path.isdir(os.path.join(LAYERS, _d, "tests", "lib")):
            sys.path.append(os.path.join(LAYERS, _d, "tests", "lib"))


# Run only when named: speed budgets (speed, a layer's speed_<name>) are what task 11 works
# towards, not a gate yet.
def only_when_named(name):
    return name == "speed" or name.startswith("speed_")


G, R, Y, D, X = "\033[32m", "\033[31m", "\033[33m", "\033[38;5;248m", "\033[0m"
if not sys.stdout.isatty():
    G = R = Y = D = X = ""


def case_files():
    """name -> path: unikit's cases, then each layer's."""
    dirs = [CASES]
    if os.path.isdir(LAYERS):
        dirs += sorted(os.path.join(LAYERS, d, "tests", "cases") for d in os.listdir(LAYERS))
    files = {}
    for d in dirs:
        if os.path.isdir(d):
            for f in os.listdir(d):
                if f.endswith(".py") and not f.startswith("_"):
                    files.setdefault(f[:-3], os.path.join(d, f))
    return files


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


def tests_of(mod):
    fns = [v for k, v in vars(mod).items() if k.startswith("test_") and callable(v)]
    return sorted(fns, key=lambda f: f.__code__.co_firstlineno)


def main(argv):
    files = case_files()
    names = sorted(files)
    want = [a for a in argv if not a.startswith("-")]
    for w in want:
        if w not in names:
            print(f"✗ no case file '{w}' · there are: {' '.join(names)}")
            return 2
    run = want or [n for n in names if not only_when_named(n)]
    passed = failed = skipped = 0
    for name in run:
        mod = load(name, files[name])
        reason = mod.skip() if hasattr(mod, "skip") else None
        if reason:
            print(f"{Y}–{X} {name}  {D}skipped: {reason}{X}")
            skipped += 1
            continue
        for fn in tests_of(mod):
            label = f"{name} · {fn.__name__[5:].replace('_', ' ')}"
            sb = Sandbox()
            Term.last = None
            t0 = time.monotonic()
            try:
                fn(sb)
            except Exception as e:  # noqa: BLE001
                failed += 1
                print(f"{R}✗{X} {label}  {D}{time.monotonic() - t0:.1f} s{X}")
                msg = str(e) if isinstance(e, AssertionError) else traceback.format_exc()
                print("    " + msg.strip().replace("\n", "\n    "))
                if Term.last is not None:
                    print(f"    {D}last screen:{X}")
                    print("    │ " + Term.last.text().replace("\n", "\n    │ "))
                print(f"    {D}sandbox kept: {sb.root}{X}")
                if Term.last is not None:
                    Term.last.close()
                continue
            if Term.last is not None:
                Term.last.close()
            sb.cleanup()
            passed += 1
            print(f"{G}✓{X} {label}  {D}{time.monotonic() - t0:.1f} s{X}")
        if hasattr(mod, "report"):
            mod.report()
    print(f"\n{passed} passed · {failed} failed" + (f" · {skipped} skipped" if skipped else ""))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
