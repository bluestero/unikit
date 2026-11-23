"""shell/complete.sh: tab completion for the commands without a completer of their own."""
import os
import subprocess

from fixture import REPO


def words(sb, *typed):
    """What Tab offers after the typed words (the last one is the word being completed)."""
    script = f'''
_work_root={REPO}
PATH="{REPO}/bin:$PATH"
. "{REPO}/shell/complete.sh"
COMP_WORDS=("$@"); COMP_CWORD=$(( $# - 1 )); COMPREPLY=()
$(complete -p "$1" | sed -n 's/.*-F \\([^ ]*\\).*/\\1/p')
printf '%s\\n' "${{COMPREPLY[@]}}"'''
    out = subprocess.run(["bash", "-c", script, "_", *typed], env=sb.env, capture_output=True, text=True, timeout=30)
    return [w for w in out.stdout.splitlines() if w]


def test_first_word_comes_from_the_help_page(sb):
    assert words(sb, "fk", "h") == ["help"]


def test_a_layer_command_adds_its_own_words_with_spaces_escaped(sb):
    script = 'printf "%s\\n" "Media API" "DaaS"'
    out = subprocess.run(["bash", "-c", f'''
_work_root={REPO}; . "{REPO}/shell/complete.sh"
demo() {{ :; }}; complete -F _work_complete demo
_work_complete_demo() {{ {script}; }}
COMP_WORDS=(demo run Med); COMP_CWORD=2; _work_complete; printf '%s\\n' "${{COMPREPLY[@]}}"'''],
        env=sb.env, capture_output=True, text=True, timeout=30)
    assert out.stdout.strip() == "Media\\ API", out.stdout
