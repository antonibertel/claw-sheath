# Claw Sheath

**Put a sheath on your AI agents to prevent them from accidentally destroying your or remote system.**

Works with **OpenClaw**, **Claude Code**, **Cursor**, and **Antigravity**.

You want the productivity of autonomous agents without the constant interruptions, but you need peace of mind that they won't purge your files or cause catastrophic damage when they inevitably go off the rails.

Claw Sneath adds an extra protection layer to let you run fully autonomous coding and personal agents. When agents hallucinate and tries to do dangerous operations, it will be asked to think deeply and justify an action.

You can enable strict mode that will also let llm-judge to evaluate the justification and decide whether to allow or deny the action.

It's very simple and naitve - a simple, dynamic security proxy for your shell. It does provide an initial feedback that can help the agent to correct itself and try again.

## Installation

Install Claw Sheath locally using our automated script (supports macOS & Linux):

```bash
curl -fsSL https://raw.githubusercontent.com/antonibertel/claw-sheath/main/install.sh | bash
```

This will:
1. Create `~/.claw-sheath/`
2. Download the core scripts and configuration.
3. Automatically compile the lightweight Go verifier.

## Quick Start & Usage

To use Claw Sheath, you must configure your AI coding agent/tool to use the `sheath-shell.sh` wrapper (or inject `sheath-env.sh`) as its primary shell environment. 

### OpenClaw & Claude Code

Run OpenClaw or Claude Code by explicitly overriding the `SHELL` variable before launch:

```bash
SHELL=/absolute/path/to/claw-sheath/src/sheath-shell.sh openclaw agent --agent main --message "Run rm important.txt"
# OR
SHELL=/absolute/path/to/claw-sheath/src/sheath-shell.sh claude
```

When the agent tries to run a destructive command without justification, it will be intercepted:
```bash
$ rm important_file.txt
claw-sheath blocked execution of 'rm':
shell check noticed that you're performing potentially unsafe operation that can harm user, are you confident and sure that it aligns with user goals and safe to perform?
if yes write down what was the user ask and what's the resolution you're trying to attempt and add as `--sheathJustify "<your justification>"` parameter
```
The agent will natively read this output, correct itself, and try again by providing the required justification flag.

### Antigravity

To launch Antigravity with the protected environment, inject the shell environment variable when opening the application from your standard terminal:

```bash
open -a "Antigravity" --env SHELL=/bin/bash --env BASH_ENV=/absolute/path/to/claw-sheath/src/sheath-env.sh
```
*(Alternatively, you can just use `open -a "Antigravity" --env SHELL=/bin/bash` if your default bash profile already sources the sheath environment.)*

### Cursor

*(Instructions for injecting the Claw Sheath into the Cursor terminal environment coming soon)*

## How It Works

1. **`config.yml`**: Defines your LLM provider and lists the restricted commands.
2. **Bash Wrappers (`sheath-env.sh`)**: Hooks into the shell environment to intercept the restricted commands.
3. **`sheath-verifier` (Go)**: Very fast and lightweight binary that queries the LLM security guard to approve or deny the action based on the agent's justification.

## Covered Disruptive Commands

Out of the box, Claw Sheath intercepts the following categories of truly dangerous, hard-to-recover commands (configurable in `config.yml`):

**Destructive file/data operations (Deletion & Wiping):**
- `rm` (File/directory removal)
- `mv` (Moving/overwriting)
- `wipe` (Secure deletion)
- `shred` (Secure deletion)
- `truncate` (File shrinking/wiping)
- `dd` (Low-level block copying/overwriting)

**Disk and Volume modification:**
- `mkfs` (Formatting file systems)
- `fdisk` (Partitioning)
- `mkswap` (Swap creation)

**Process & System Disruption:**
- `kill` (Terminating processes)
- `killall` (Terminating all instances)
- `pkill` (Terminating by name)
- `sudo fdesetup disable` (Disabling FileVault encryption)
- `sudo nvram -c` (Clearing NVRAM variables)
- `kubectl delete` (Kubernetes resource deletion)

*(Note: Claw Sheath focuses on preventing permanent data loss and system disruption, rather than purely intercepting minor permission changes like `chmod` by default, though these can easily be added to your config).*

---

> **Tested on:** macOS
> 
> **⚠️ Disclaimer:** Claw Sheath is a **simple preventative measure**, not a bulletproof sandbox or military-grade isolation environment. It is designed to catch common hallucination mistakes and prevent an AI from going completely wild with standard commands. A truly malicious agent could still theoretically circumvent this if they try hard enough.

*Stay productive. Stay safe.*
