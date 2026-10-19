# Copyright (c) 2026 Abdulrahman Aljoudi (aaljoudi)
# SPDX-License-Identifier: MIT

# script-arg-hints.zsh
#
# Shows ghost-text argument hints for executable script files.
#
# Expected script format:
#   line 1: anything (typically a shebang)
#   line 2: usage comment, e.g.
#           # ./run <testName> <numIterations> <outFile>
#
# Source this file from ~/.zshrc.

# Give a useful error when accidentally sourced by another shell.
if [ -z "${ZSH_VERSION:-}" ]; then
    printf "%s\n" "Ghost Args requires Zsh; source it from your .zshrc." >&2
    return 1
fi

typeset -g SCRIPT_ARG_HINT_STYLE="${SCRIPT_ARG_HINT_STYLE:-fg=8}"
typeset -g _SCRIPT_ARG_HINT_LAST_TEXT=""
typeset -g _SCRIPT_ARG_HINT_LAST_HIGHLIGHT=""

_script_arg_hint_clear() {
    emulate -L zsh

    # Remove only the highlight entry created by this plugin.
    if [[ -n "$_SCRIPT_ARG_HINT_LAST_HIGHLIGHT" ]]; then
        local -a kept_highlights
        local highlight
        local -i removed=0

        # Use literal comparison rather than a pattern subtraction.  Styles are
        # user-configurable and can legally contain glob metacharacters.
        for highlight in "${region_highlight[@]}"; do
            if (( ! removed )) && [[ "$highlight" == "$_SCRIPT_ARG_HINT_LAST_HIGHLIGHT" ]]; then
                removed=1
            else
                kept_highlights+=("$highlight")
            fi
        done
        region_highlight=("${kept_highlights[@]}")
        _SCRIPT_ARG_HINT_LAST_HIGHLIGHT=""
    fi

    # Clear POSTDISPLAY only if it still contains our own hint.
    # This reduces interference with other ZLE plugins.
    if [[ -n "$_SCRIPT_ARG_HINT_LAST_TEXT" && "$POSTDISPLAY" == "$_SCRIPT_ARG_HINT_LAST_TEXT" ]]; then
        POSTDISPLAY=""
    fi

    _SCRIPT_ARG_HINT_LAST_TEXT=""
}

_script_arg_hint_is_redirection() {
    emulate -L zsh
    setopt extendedglob

    # zsh's lexer keeps a file-descriptor prefix attached (for example, 2>),
    # so remove only leading decimal digits before comparing the operator.
    local operator=${1##[0-9]#}
    case "$operator" in
        '<'|'>'|'>>'|'>|'|'<>'|'>&'|'<&'|'<<'|'<<-'|'<<<'|'&>'|'&>>') return 0 ;;
        *) return 1 ;;
    esac
}

_script_arg_hint_update() {
    emulate -L zsh
    setopt extendedglob
    unsetopt globsubst

    _script_arg_hint_clear

    # Keep hints visually attached to what the user is currently typing.
    # If the cursor is in the middle of the command, don't show a hint.
    (( CURSOR == ${#BUFFER} )) || return 0

    # Parse the current command line using zsh's shell-word lexer. Quoted
    # strings count as one argument, and operators remain distinguishable from
    # quoted operator characters.
    local -a words
    words=("${(@z)BUFFER}")

    (( ${#words} >= 1 )) || return 0

    # Work with the simple command at the cursor, not necessarily the first
    # command in BUFFER. This covers common forms such as:
    #   make setup && ./run <args>
    #   printf x | ./run <args>
    local -i command_start=1
    local -i i
    for (( i = 1; i <= ${#words}; ++i )); do
        case "${words[i]}" in
            ';'|'&'|'&&'|'|'|'|&'|'||'|$'\n') command_start=$(( i + 1 )) ;;
        esac
    done

    (( command_start <= ${#words} )) || return 0

    # Permit environment assignments and redirections immediately before the
    # executable. A redirection consumes the following lexer token as its
    # target.
    while (( command_start <= ${#words} )); do
        local candidate="${(Q)words[command_start]}"
        if [[ "$candidate" == [A-Za-z_][A-Za-z0-9_]#=* ]]; then
            (( ++command_start ))
        elif _script_arg_hint_is_redirection "${words[command_start]}"; then
            (( command_start += 2 ))
        else
            break
        fi
    done

    (( command_start <= ${#words} )) || return 0

    # Remove shell quoting from the command token.
    local cmd="${(Q)words[command_start]}"

    # Resolve the two ways users commonly invoke a script without spelling a
    # literal path: ~/relative/path and a command found through PATH. Avoid
    # eval-style expansion here; command text must never be executed by a
    # redraw hook.
    local cmd_path="$cmd"
    if [[ "$cmd" == '~/'* ]]; then
        cmd_path="$HOME/${cmd#\~/}"
    elif [[ "$cmd" != */* ]]; then
        cmd_path="${commands[$cmd]-}"
    fi

    # The typed command itself must be a real executable file.
    [[ -n "$cmd_path" && -f "$cmd_path" && -r "$cmd_path" && -x "$cmd_path" ]] || return 0

    # Read exactly the first two lines without launching sed/head on every keypress.
    local first_line second_line
    {
        IFS= read -r first_line || [[ -n "$first_line" ]] || return 0
        IFS= read -r second_line || [[ -n "$second_line" ]] || return 0
    } < "$cmd_path"

    # A CRLF file leaves the carriage return on the value returned by read.
    second_line="${second_line%$'\r'}"

    # Trim leading whitespace from line 2.
    second_line="${second_line##[[:space:]]#}"

    # Line 2 must be a comment.
    [[ "$second_line" == \#* ]] || return 0

    # Remove "#" and whitespace immediately after it.
    local usage="${second_line#\#}"
    usage="${usage##[[:space:]]#}"

    [[ -n "$usage" ]] || return 0

    # Usage comments are untrusted file content: never render terminal controls.
    [[ "$usage" != *[[:cntrl:]]* ]] || return 0

    # The specification format is intentionally simple:
    #   ./run <testName> <numIterations> <outFile>
    #
    # Split on whitespace rather than shell operators, because <name>
    # is documentation syntax here, not input-redirection syntax.
    local -a usage_words
    usage_words=(${=usage})

    # Locate the first placeholder instead of assuming the command occupies a
    # single whitespace-delimited word. This lets a quoted executable path (or
    # its basename in the usage comment) contain spaces.
    local -i first_arg=0
    for (( i = 1; i <= ${#usage_words}; ++i )); do
        if [[ "${usage_words[i]}" == '<'* ]]; then
            first_arg=$i
            break
        fi
    done
    (( first_arg > 1 )) || return 0

    # Make sure the usage comment refers to this script.
    # Comparing the final path component allows:
    #   typed:   ./run
    #   comment: ./run
    # and also permits an absolute path to the same-named script.
    local documented_cmd="${(j: :)usage_words[1,$(( first_arg - 1 ))]}"
    documented_cmd="${(Q)documented_cmd}"
    [[ "${documented_cmd:t}" == "${cmd:t}" ||
       "${documented_cmd:t}" == "${cmd_path:t}" ]] || return 0

    # Count real arguments after the command, excluding redirection operators
    # and their targets wherever they occur in the simple command.
    local -i entered_args=0
    for (( i = command_start + 1; i <= ${#words}; ++i )); do
        if _script_arg_hint_is_redirection "${words[i]}"; then
            (( ++i ))
        else
            (( ++entered_args ))
        fi
    done
    local -i documented_args=$(( ${#usage_words} - first_arg + 1 ))

    # Nothing left to hint.
    (( entered_args < documented_args )) || return 0

    # Build the remaining placeholders.
    #
    # Example:
    #   usage:  ./run <testName> <numIterations> <outFile>
    #   buffer: ./run pizza
    #
    # entered_args = 1, so show:
    #   <numIterations> <outFile>
    local -a remaining
    for (( i = first_arg + entered_args; i <= ${#usage_words}; ++i )); do
        remaining+=("${usage_words[i]}")
    done

    local hint=" ${(j: :)remaining}"

    # Usage hints take priority over history suggestions for this command only.
    # Remove the autosuggestion's highlight before taking over shared display.
    if (( $+functions[_zsh_autosuggest_highlight_reset] )); then
        _zsh_autosuggest_highlight_reset
    fi
    POSTDISPLAY="$hint"
    _SCRIPT_ARG_HINT_LAST_TEXT="$hint"

    # Highlight only the non-editable ghost-text portion.
    local -i start=${#BUFFER}
    local -i end=$(( start + ${#POSTDISPLAY} ))

    _SCRIPT_ARG_HINT_LAST_HIGHLIGHT="$start $end $SCRIPT_ARG_HINT_STYLE"
    region_highlight+=("$_SCRIPT_ARG_HINT_LAST_HIGHLIGHT")

    return 0
}

# zsh-autosuggestions can redraw asynchronously, without running the normal
# pre-redraw hook. Its public widgets must refresh hints after their response,
# and must never mistake our documentation for an accept-able history value.
_script_arg_hint_autosuggest_widget() {
    _script_arg_hint_clear
    "_script_arg_hint_original${funcstack[1]}" "$@"
    local -i hint_widget_status=$?
    _script_arg_hint_update
    # Async suggestion responses need their own refresh; ordinary keystrokes
    # are redrawn by ZLE after the widget returns.
    if [[ ${funcstack[1]} == _zsh_autosuggest_widget_suggest ]]; then
        zle -R
    fi
    return $hint_widget_status
}

_script_arg_hint_setup_autosuggestions() {
    emulate -L zsh
    local action widget_function
    for action in modify suggest accept partial_accept execute clear; do
        widget_function="_zsh_autosuggest_widget_$action"
        (( $+functions[$widget_function] )) || continue
        # Function copies preserve the plugin's existing implementation and
        # avoid nested wrappers when .zshrc is sourced more than once.
        if [[ "$functions[$widget_function]" != "$functions[_script_arg_hint_autosuggest_widget]" ]]; then
            functions[_script_arg_hint_original${widget_function}]="$functions[$widget_function]"
            functions[$widget_function]="$functions[_script_arg_hint_autosuggest_widget]"
        fi
    done
}

# Register the updater with ZLE's redraw hook.
if [[ -o interactive ]]; then
    zmodload zsh/zle
    autoload -Uz add-zsh-hook add-zle-hook-widget
    _script_arg_hint_setup_autosuggestions
    add-zsh-hook precmd _script_arg_hint_setup_autosuggestions
    add-zle-hook-widget -d line-pre-redraw _script_arg_hint_update 2>/dev/null
    add-zle-hook-widget line-pre-redraw _script_arg_hint_update
    add-zle-hook-widget -d line-finish _script_arg_hint_clear 2>/dev/null
    add-zle-hook-widget line-finish _script_arg_hint_clear
fi
