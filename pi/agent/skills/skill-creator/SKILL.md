---
name: skill-creator
description: Scaffold a new pi Agent Skill (SKILL.md + frontmatter) and install it for the user. Use whenever the user asks to create, scaffold, author, or add a new skill. Always prompts the user whether the skill should be symlinked, and if so, where the real (source-of-truth) skill directory should live.
---

# Skill Creator

Create a new pi Agent Skill end-to-end: gather intent, write a spec-compliant
`SKILL.md`, then install it — either as a plain directory under the pi skills dir, or
as a symlink whose real directory lives in a source-of-truth location (e.g. a dotfiles
repo) so it can be version-controlled and re-installed elsewhere.

## When to use

Trigger this skill whenever the user asks to create / scaffold / author / add a new
skill. Do **not** trigger it for editing an existing skill's body (just edit the file).

## Step 1 — Gather the skill spec

Ask the user (or infer from their request) the following, then confirm before writing:

- **name** — must satisfy the pi/Agent Skills rules:
  - 1-64 chars, lowercase `a-z`, digits `0-9`, hyphens only
  - no leading/trailing hyphen, no consecutive hyphens
  - good: `pdf-tools`, `data-analysis`; bad: `PDF`, `-x`, `a--b`
- **description** — **HARD LIMIT: 1024 characters** (pi rejects/flags any longer as a
  skill conflict). Count the characters before writing the file and trim if needed.
  Must state **what it does AND when to use it**.
  Be specific and trigger-rich (the description is the only thing always in context).
  Prefer parenthetical trigger lists over repeated `"quoted phrases"`; drop redundant
  synonyms rather than exceeding the limit. Keep meaning intact while trimming.
- **body** — the instructions, setup, usage, and any helper scripts/assets.

## Step 2 — Decide the install location (ALWAYS prompt)

The pi global skills dir is `~/.pi/agent/skills/`. Ask the user **both** questions:

1. **"Do you want this skill symlinked, or created directly in the pi skills dir?"**
2. If symlinked: **"Where should the real skill directory live (source path)?"**
   - Suggest a sensible default if you know one. In this dotfiles setup the convention
     is `~/.dotfiles/nvim-config/pi/agent/skills/` for generic skills (a public repo) and
     `~/.dotfiles/Dsych-config/pi/agent/skills/` for skills tied to internal tooling;
     each repo's `install.sh` re-symlinks everything under `pi/agent/skills/` on a fresh
     machine. Offer that default but let the user override.

Do not proceed to write until the user has answered both. Never assume symlink vs direct.

## Step 3 — Create the skill

Let `NAME` be the skill name, `PI_SKILLS="$HOME/.pi/agent/skills"`.

### Option A — direct (no symlink)

```bash
mkdir -p "$PI_SKILLS/<NAME>"
# write SKILL.md into "$PI_SKILLS/<NAME>/SKILL.md"
```

### Option B — symlinked from a source location

`SRC` = the source path the user gave (the directory that will *contain* the skill dir).

```bash
mkdir -p "<SRC>/<NAME>"
# write SKILL.md into "<SRC>/<NAME>/SKILL.md"
ln -s "<SRC>/<NAME>" "$PI_SKILLS/<NAME>"
```

If `$PI_SKILLS/<NAME>` already exists, stop and ask the user how to proceed (overwrite,
back up to `.old`, or pick a different name) — never clobber silently.

### SKILL.md template

````markdown
---
name: <NAME>
description: <what it does + when to use it; specific, trigger-rich>
---

# <Human Title>

## Setup
<one-time setup, if any>

## Usage
<ordered, concrete, actionable instructions>
````

## Step 4 — Verify

- Confirm `SKILL.md` exists and frontmatter is valid (name rules + description present).
- Verify the description is ≤ 1024 characters, e.g.:
  `awk '/^description: /{sub(/^description: /,"");print length($0)}' "$PI_SKILLS/<NAME>/SKILL.md"`
  Trim it if the count exceeds 1024.
- If symlinked, confirm `readlink "$PI_SKILLS/<NAME>"` points at `<SRC>/<NAME>`.
- pi autodiscovers skills (including symlinked dirs) at startup, so the new skill is
  available in the **next** session. Tell the user to start a new session (or use
  `/skill:<NAME>`) to load it.
- If the source dir is a tracked repo (e.g. dotfiles), remind the user to commit it.
