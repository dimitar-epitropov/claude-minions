---
name: debugger
description: Systematically debug a bug, test failure, crash, or any unexpected behavior — reproduce it, find the real root cause, and verify the fix. Use this whenever something is broken or behaving wrong: "this is failing", "why is X happening", "fix this bug", "the test breaks", "it crashes when...", a stack trace, or any "this should work but doesn't". Always checks docs/minions/DEBUG.md first for project-specific debugging instructions. Prefer this skill even when the user doesn't say "debug" but clearly wants something broken made to work.
---

# Debugger

You find the *root cause* of a bug and fix it — not the first plausible-looking symptom. Guessing wastes time and tends to patch over the real problem. The discipline below keeps you honest.

## Step 0 — Read project debugging instructions first

Before anything else, check for `docs/minions/DEBUG.md` (relative to the working directory). If it exists, read it and follow it — it holds project-specific knowledge you can't infer: how to reproduce, which commands run the tests, where logs live, known pitfalls, env setup. This context usually saves the most time, so don't skip it.

If it doesn't exist, proceed with the steps below.

## The loop

1. **Reproduce it.** Get a reliable, minimal way to trigger the bug. If you can't reproduce it, you can't confirm you fixed it — so this comes before any fix. Capture the exact error, stack trace, and inputs.

2. **Form a hypothesis from evidence.** State what you *think* is wrong and *why*, grounded in what you actually observed (logs, traces, values) — not a hunch. Add logging or inspect state to gather more if the evidence is thin.

3. **Locate the root cause.** Trace back from the symptom to the thing that actually caused it. Ask "why" until you hit the real source — a symptom three layers up is the wrong place to patch.

4. **Fix the cause, minimally.** Change what's actually broken, not the surrounding code. Avoid speculative "while I'm here" edits — they muddy whether your fix worked.

5. **Verify.** Re-run the reproduction from step 1 and confirm it now passes. Run nearby tests too, so the fix didn't break something adjacent. State the evidence — don't just claim it's fixed.

## When stuck

If two hypotheses fail, stop guessing. Re-read the error literally, question an assumption you've been treating as true, or narrow the repro further (bisect, comment things out). The bug is usually somewhere you assumed was fine.
