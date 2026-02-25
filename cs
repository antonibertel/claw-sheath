#!/bin/bash

# Determine our location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ENV_FILE="${SCRIPT_DIR}/src/sheath-env.sh"

export SHELL="$SCRIPT_DIR/cs"
export BASH_ENV="$ENV_FILE"

# Make sure we don't accidentally source it interactively unless needed,
# but our primary target is bash -c, which automatically sources BASH_ENV.
# If bash is running interactively, BASH_ENV isn't naturally sourced, 
# so we can explicitly source it here just in case.
if [[ -f "$ENV_FILE" ]]; then
    source "$ENV_FILE"
else
    echo -e "\x1b[31mclaw-sheath error:\x1b[0m Environment file not found at $ENV_FILE" >&2
    exit 1
fi

if [[ "$1" == "-c" ]]; then
    # We are acting as the shell proxy (invoked by the agent)
    exec bash "$@"
else
    # We are acting as the launcher (invoked by the user: `cs openclaw`)
    if [[ $# -eq 0 ]]; then
        echo "Usage: cs <command_to_protect>"
        echo "Example: cs openclaw agent --agent main"
        exit 1
    fi
    exec "$@"
fi
