#!/bin/bash

# The core wrapper logic.
# Usage: _sheath_wrapper <command_name> "$@"
_sheath_wrapper() {
    local cmd="$1"
    shift
    
    local safe_cmd="${cmd//-/_}"
    local varname="SHEATH_RULES_${safe_cmd}"
    # Read the stored rules for this command
    local rules="${!varname}"
    
    local args=()
    local has_justify=0
    local justification=""
    
    # Extract --sheathJustify if present
    while [[ $# -gt 0 ]]; do
        if [[ "$1" == "--sheathJustify" ]]; then
            has_justify=1
            shift
            if [[ $# -gt 0 ]]; then
                justification="$1"
                shift
            else
                echo -e "\x1b[31mclaw-sheath error:\x1b[0m --sheathJustify requires a string argument." >&2
                return 1
            fi
        else
            args+=("$1")
            shift
        fi
    done
    
    # Reconstruct arguments string to check substring (space padded for boundary matching)
    local args_str=" ${args[*]} "
    local requires_justify=0
    
    # If the rules variable is strictly empty, it means we must intercept ALL invocations.
    if [[ -z "$rules" ]]; then
        requires_justify=1
    else
        local IFS=$'\n'
        for rule in $rules; do
            # If a rule inside the multi-line string is completely empty, it means "intercept any invocation"
            if [[ -z "$rule" ]]; then
                requires_justify=1
                break
            fi
            
            # Check if the rule substring exists exactly in the arguments.
            if [[ "$args_str" == *" $rule "* ]]; then
                requires_justify=1
                break
            fi
        done
    fi
    
    # If this specific command + argument combination doesn't match our rules, run normally
    if [[ $requires_justify -eq 0 ]]; then
        command "$cmd" "${args[@]}"
        return $?
    fi
    
    # If it is restricted but no justification provided, block it
    if [[ $has_justify -eq 0 ]]; then
        echo -e "\x1b[31mclaw-sheath blocked execution of '${cmd}':\x1b[0m" >&2
        echo "shell check noticed that you're performing potentially unsafe operation that can harm user, are you confident and sure that it aligns with user goals and safe to perform?" >&2
        echo "if yes write down what was the user ask and what's the resolution you're trying to attempt and add as \`--sheathJustify \"<your justification>\"\` parameter" >&2
        return 1
    fi
    
    # We have a justification. Let's call the Go Verifier.
    local script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
    local verifier_bin="${script_dir}/verifier/sheath-verifier"
    
    # Fail-safe mechanism: If ANYTHING goes wrong, we execute the command to prevent breaking the environment.
    local verifier_status=0
    
    if [[ ! -x "$verifier_bin" ]]; then
        # Verifier missing, fail open passively
        :
    else
        # Reconstruct the exact command string passed by the user
        local full_cmd="$cmd ${args[*]}"
        
        # Capture the verifier output. We wrap in a subshell and OR with true to prevent `set -e` from crashing the host shell.
        local verifier_output
        verifier_output=$("$verifier_bin" --config "$CONFIG_FILE" --cmd "$full_cmd" --justify "$justification" 2>&1) || verifier_status=$?
        
        if [[ $verifier_status -eq 1 ]]; then
            # The LLM explicitly rejected the justification
            echo -e "\x1b[31mclaw-sheath blocked execution:\x1b[0m\n$verifier_output" >&2
            return 1
        elif [[ $verifier_status -ne 0 ]]; then
            # The LLM binary crashed or hit an unexpected error (not code 1/rejected).
            # FAIL OPEN: We allow the command so the AI isn't stuck.
            echo -e "\x1b[33mclaw-sheath verifier error (${verifier_status}): $verifier_output\x1b[0m" >&2
            echo -e "\x1b[33mFailing open and allowing command.\x1b[0m" >&2
        else
            # Exit code 0, verifier explicitly allowed it.
            if [[ -n "$verifier_output" ]]; then
                echo -e "\x1b[33mclaw-sheath:\x1b[0m $verifier_output" >&2
            fi
        fi
    fi
    
    # Execute the actual binary
    command "$cmd" "${args[@]}"
}

# Load the dynamic configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config.yml"

if [[ -f "$CONFIG_FILE" ]]; then
    while read -r line; do
        # Ignore comments and empty lines
        [[ -z "$line" ]] && continue
        [[ "$line" =~ ^[[:space:]]*# ]] && continue
        
        # Match list items
        if [[ "$line" =~ ^[[:space:]]*-[[:space:]]+(.*) ]]; then
            val="${BASH_REMATCH[1]}"
            
            # Remove surrounding quotes if present
            val="${val%\"}"
            val="${val#\"}"
            val="${val%\'}"
            val="${val#\'}"
            val="${val%\"}"
            
            cmd="${val%% *}"
            rule="${val#* }"
            
            # If the command has no arguments specified, rule should be empty
            if [[ "$cmd" == "$rule" ]]; then
                rule=""
            fi
            
            safe_cmd="${cmd//-/_}"
            varname="SHEATH_RULES_${safe_cmd}"
            
            if eval "[[ -n \"\${$varname+x}\" ]]"; then
                # Variable exists, append rule with a newline (using an actual newline in the eval string)
                eval "$varname=\"\${$varname}
$rule\""
            else
                # Variable doesn't exist, initialize and export the function override
                eval "$varname=\"$rule\""
                eval "
$cmd() {
    _sheath_wrapper $cmd \"\$@\"
}
export -f $cmd"
            fi
        fi
    done < "$CONFIG_FILE"
    
    # Note: System binaries that execute commands directly (like xargs, find -exec, sudo)
    # may naturally bypass bash function tracking if not explicitly handled or tracked themselves in the config.
    shopt -s expand_aliases
    alias sudo='sudo '
    alias time='time '
    alias nice='nice '
else
    echo -e "\x1b[33mclaw-sheath warning: config.yml not found, no commands restricted.\x1b[0m" >&2
fi
