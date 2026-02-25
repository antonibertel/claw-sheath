#!/bin/bash

# Determine the absolute path to our environment injection script
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
ENV_FILE="${SCRIPT_DIR}/sheath-env.sh"

export BASH_ENV="$ENV_FILE"

# Make sure we don't accidentally source it interactively unless needed,
# but our primary target is bash -c, which automatically sources BASH_ENV.
# If bash is running interactively, BASH_ENV isn't naturally sourced, 
# so we can explicitly source it here just in case.
source "$ENV_FILE"

shell="${SHELL:-/bin/bash}"

# Replace the current process with the underlying shell, passing all arguments along.
exec "$shell" "$@"
