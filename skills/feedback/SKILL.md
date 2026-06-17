---
name: feedback
description: >-
  Use when something about minions itself was annoying, wrong, or could be better — "minions
  feedback", "log this gripe", "the planner ignored X", "that step was overkill". Appends a
  timestamped entry to docs/minions/feedback.md while the friction is fresh. For feedback about
  the framework, not about the user's own project.
argument-hint: "[the gripe]"
---

# minions: feedback

Announce: **"Logging minions feedback."** Then be quick — this skill exists to capture friction
in seconds, not to start a discussion.

## What to do

1. Resolve the minions root (`.minions-root` if present, else `docs/minions/`). If
   `<root>/feedback.md` doesn't exist, this project isn't initialized — offer `/minions:init`,
   or just create `feedback.md` from the template if the user clearly wants to log something now.
2. The gripe is `$ARGUMENTS` (everything the user typed). If it's empty, ask once: "What about
   minions should I log?" — one line is enough.
3. Append to `<root>/feedback.md` (newest at the bottom), in the file's format:

```
## <today's date> — <one-line gist of the gripe>
<a sentence of context: which skill/agent, what you expected, what happened — pull this from the
recent conversation if it's obvious, otherwise just record what the user said>
```

4. Confirm in one line that it's logged. **Don't** try to fix the framework now, debate the
   point, or dispatch anything — capturing it raw is the whole job. The extender agent turns
   `feedback.md` into eval cases and skill edits later (design §11.18).

## Why so minimal

Friction is only captured if capturing it is frictionless. Anything heavier and you'd skip it,
and the framework would stop learning from real use.
