#!/bin/zsh
# Copyright (c) 2026 Abdulrahman Aljoudi (aaljoudi)
# SPDX-License-Identifier: MIT

emulate -L zsh
setopt errexit nounset pipefail

typeset test_dir=${0:A:h}
typeset project_dir=${test_dir:h}

source "$project_dir/script-arg-hints.zsh"

typeset -gi tests_run=0

fail() {
    print -u2 -r -- "FAIL: $1"
    return 1
}

assert_equal() {
    local expected=$1 actual=$2 description=$3
    (( ++tests_run ))
    [[ "$actual" == "$expected" ]] || fail "$description (expected ${(qqq)expected}, got ${(qqq)actual})"
}

update_for() {
    BUFFER=$1
    CURSOR=${#BUFFER}
    POSTDISPLAY=""
    region_highlight=()
    _SCRIPT_ARG_HINT_LAST_TEXT=""
    _SCRIPT_ARG_HINT_LAST_HIGHLIGHT=""
    _script_arg_hint_update
}

typeset script="$test_dir/fixtures/hint-script"
typeset spaced_script="$test_dir/fixtures/script with spaces"

update_for "$script"
assert_equal ' <first> <second> <third>' "$POSTDISPLAY" 'shows all arguments'
assert_equal "${#BUFFER} $(( ${#BUFFER} + ${#POSTDISPLAY} )) $SCRIPT_ARG_HINT_STYLE" \
    "$region_highlight[1]" 'highlights the ghost text'

update_for "$script alpha"
assert_equal ' <second> <third>' "$POSTDISPLAY" 'advances after one argument'

update_for "$script \"alpha beta\""
assert_equal ' <second> <third>' "$POSTDISPLAY" 'counts a quoted value as one argument'

update_for "$script \"unfinished"
assert_equal ' <second> <third>' "$POSTDISPLAY" 'tolerates an unfinished quote during editing'

update_for "\"$spaced_script\" value"
assert_equal ' <two>' "$POSTDISPLAY" 'supports a quoted executable path'

typeset old_path=$PATH
PATH="$test_dir/fixtures:$PATH"
rehash
update_for 'hint-script'
assert_equal ' <first> <second> <third>' "$POSTDISPLAY" 'resolves an executable through PATH'
PATH=$old_path
rehash

typeset old_home=$HOME
HOME="$test_dir/fixtures"
update_for '~/hint-script alpha'
assert_equal ' <second> <third>' "$POSTDISPLAY" 'resolves a path beneath home'
HOME=$old_home

update_for "true && $script alpha"
assert_equal ' <second> <third>' "$POSTDISPLAY" 'uses the command after a boolean operator'

update_for "print x | $script"
assert_equal ' <first> <second> <third>' "$POSTDISPLAY" 'uses the command after a pipeline'

update_for "MODE=test $script alpha beta"
assert_equal ' <third>' "$POSTDISPLAY" 'skips leading environment assignments'

update_for "$script > output.log"
assert_equal ' <first> <second> <third>' "$POSTDISPLAY" 'does not count a redirection as an argument'

update_for "$script alpha 2> errors.log"
assert_equal ' <second> <third>' "$POSTDISPLAY" 'ignores a file-descriptor redirection after an argument'

update_for "> output.log $script alpha"
assert_equal ' <second> <third>' "$POSTDISPLAY" 'supports a redirection before the executable'

BUFFER=$script
CURSOR=${#BUFFER}
POSTDISPLAY=' other-plugin'
region_highlight=('0 1 bold')
_SCRIPT_ARG_HINT_LAST_TEXT=""
_SCRIPT_ARG_HINT_LAST_HIGHLIGHT=""
_script_arg_hint_update
assert_equal ' <first> <second> <third>' "$POSTDISPLAY" 'usage hints take priority over another plugin display'
assert_equal '0 1 bold' "$region_highlight[1]" 'preserves unrelated highlights'

BUFFER='not-a-real-command-for-ghost-args'
CURSOR=${#BUFFER}
POSTDISPLAY=' other-plugin'
_SCRIPT_ARG_HINT_LAST_TEXT=''
_SCRIPT_ARG_HINT_LAST_HIGHLIGHT=''
_script_arg_hint_update
assert_equal ' other-plugin' "$POSTDISPLAY" 'preserves other suggestions for commands without usage hints'

update_for "$script"
typeset own_highlight=$_SCRIPT_ARG_HINT_LAST_HIGHLIGHT
region_highlight=('0 1 bold' "$own_highlight" '2 3 underline')
_script_arg_hint_clear
assert_equal '' "$POSTDISPLAY" 'clears owned ghost text'
assert_equal '0 1 bold|2 3 underline' "${(j:|:)region_highlight}" 'clears only the owned highlight'

update_for "$script alpha beta gamma"
assert_equal '' "$POSTDISPLAY" 'hides the hint when all arguments are present'

update_for "$script"
CURSOR=$(( ${#BUFFER} - 1 ))
_script_arg_hint_update
assert_equal '' "$POSTDISPLAY" 'hides the hint when the cursor is not at the end'

# Temporary fixtures cover untrusted input without touching the checkout.
typeset temp_dir=$(mktemp -d "${TMPDIR:-/tmp}/ghost-args-unit.XXXXXXXX")
trap 'rm -rf "$temp_dir"' EXIT
cp "$script" "$temp_dir/hint-script"
chmod -x "$temp_dir/hint-script"
update_for "$temp_dir/hint-script"
assert_equal '' "$POSTDISPLAY" 'ignores non-executable files'
chmod +x "$temp_dir/hint-script"
printf '#!/bin/sh\n# ./hint-script <first> <second>\r\n' > "$temp_dir/hint-script"
update_for "$temp_dir/hint-script"
assert_equal ' <first> <second>' "$POSTDISPLAY" 'supports CRLF usage comments'
printf '#!/bin/sh\n# ./hint-script <first>\033[2J\n' > "$temp_dir/hint-script"
update_for "$temp_dir/hint-script"
assert_equal '' "$POSTDISPLAY" 'rejects terminal control characters in comments'
printf '#!/bin/sh\n# ./different-name <first>\n' > "$temp_dir/hint-script"
update_for "$temp_dir/hint-script"
assert_equal '' "$POSTDISPLAY" 'ignores usage for another command'
update_for "$script \$(touch $temp_dir/should-not-exist)"
assert_equal ' <second> <third>' "$POSTDISPLAY" 'counts a substitution without executing it'
assert_equal 'no' "$([[ -e "$temp_dir/should-not-exist" ]] && print yes || print no)" 'never executes command substitutions'
update_for "$script ''"
assert_equal ' <second> <third>' "$POSTDISPLAY" 'counts an empty quoted argument'
update_for "$script ';'"
assert_equal ' <second> <third>' "$POSTDISPLAY" 'quoted operators are arguments'
update_for "$script alpha "
assert_equal ' <second> <third>' "$POSTDISPLAY" 'trailing space does not add an argument'

print -r -- "PASS: $tests_run assertions"
