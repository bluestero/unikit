"""lib/migrate.sh: the old names move to unikit's, once (scratch HOME)."""
import os
import shutil
import subprocess

from fixture import REPO

LIST = """\
# Where the repos live: ~/Work/unix-toolkit
AIRPR=~/Work/AirPR
@airpr
~/Work/unix-toolkit
  ~/Work/unix-toolkit/   me/unix-toolkit
{home}/Work/unix-toolkit
~/Old/unix-toolkit
~/Kept/unix-toolkit
$AIRPR/unix-toolkit
~/Work/unix-toolkit-fork"""


def migrate(sb, shell):
    subprocess.run([shell, "-c", f'. "{REPO}/lib/migrate.sh" && unikit_migrate'],
                   env=sb.env, check=True, timeout=30)


def check(sb, shell):
    for d in ("~/Work/unikit", "~/Old", "~/Kept/unix-toolkit", "~/Kept/unikit"):
        os.makedirs(sb.path(d), exist_ok=True)
    f = sb.write("~/.config/ws/workspaces", LIST.format(home=sb.home))
    migrate(sb, shell)
    assert open(f).read() == f"""\
# Where the repos live: ~/Work/unix-toolkit
AIRPR=~/Work/AirPR
@airpr
~/Work/unikit
  ~/Work/unikit   me/unix-toolkit
{sb.home}/Work/unikit
~/Old/unix-toolkit
~/Kept/unix-toolkit
$AIRPR/unix-toolkit
~/Work/unix-toolkit-fork
""", open(f).read()
    before = os.stat(f).st_mtime_ns
    migrate(sb, shell)                       # nothing left to change: the file stays as it is
    assert os.stat(f).st_mtime_ns == before and not os.path.exists(f + ".unikit-tmp")


def test_ws_list_lines_naming_a_gone_unix_toolkit_point_at_unikit_in_bash(sb):
    check(sb, "bash")


def test_the_same_in_zsh(sb):
    if shutil.which("zsh"):
        check(sb, "zsh")
