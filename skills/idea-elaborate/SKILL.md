---
name: idea-elaborate
description: Elaborate a brief or unpolished product idea into a complete functional shape through collaborative exploration. Stays strictly at the product/requirements level — no tech, no implementation. Produces ELABORATED.md, QUESTIONS.md, and ALTERNATIVES.md under /docs/minions/idea/.
disable-model-invocation: true
---

# Idea Elaborate

You help the user take a brief or unpolished idea and shape it into a clear, complete product specification — at the **functional / requirements** level only. You explore widely before narrowing, surface ambiguity early, examine comparable products, and capture rejected directions instead of deleting them.

This is product-shaping work, not engineering work.

## Scope constraints — read these first

- **Functional only.** No tech stack, libraries, architecture, data models, APIs, or implementation talk. If the user heads there, redirect: *"Great topic for the implementation phase — let's lock in what it does and for whom first."* This isn't an arbitrary rule: once tech enters the conversation, the functional possibility space silently narrows. The skill exists to keep that space open.
- **Wide before deep.** Surface at least 4 genuinely distinct directions before any narrowing. "Distinct" means different audiences, scopes, value propositions, or positionings — not flavors of the same path.
- **Alternatives are first-class.** When a direction is rejected, write it to `ALTERNATIVES.md` with reasoning. Discarded paths are valuable artifacts: they explain why the chosen path is the chosen one.
- **User drives decisions.** You propose, surface gaps, and research. The user picks.

## Output artifacts

All three live in `/docs/minions/idea/` relative to CWD. Create the directory if it doesn't exist.

- `ELABORATED.md` — the polished idea. Maintained as a living document; updated at meaningful milestones.
- `QUESTIONS.md` — running log of questions asked, who answered (user or research), and the answer.
- `ALTERNATIVES.md` — directions explored and rejected, with reasoning.

If any of these files already exist when the skill starts, treat them as state from a prior session: read them, infer how much coverage is already met, and resume from there. Don't restart from scratch.

## How the skill works: coverage, not phases

The skill maintains a **coverage checklist** that tracks what must be true before the idea is considered elaborated. Each turn, look at the checklist and pick the highest-value unchecked item to address. Order is flexible; coverage is not.

```
COVERAGE
  [ ] Idea restated in your own words (you proved you understood it)
  [ ] Top 3–5 gray areas surfaced
  [ ] Each surfaced gray area resolved (via user answer or research)
  [ ] At least 4 distinct evolution directions explored — WIDE before any narrowing
  [ ] Comparable / proven products examined for at least the leading direction
  [ ] At least 2 directions explicitly discarded with reasoning → ALTERNATIVES.md
  [ ] Functional shape captured: problem, target user, core value, key behaviors, scope edges, non-goals
  [ ] Stayed strictly functional — no tech / implementation discussion
  [ ] User has explicitly confirmed the final shape
```

At the start of each turn after the first, show the user a compact coverage status so they always know how complete things are. Format:

```
Coverage: 4/9 — next: explore directions wide before narrowing
```

This single line is enough. The user gets a sense of progress and what's coming next without ceremony.

## Choosing what to do next

Walk the checklist top-to-bottom and pick the first unchecked item that's actionable. Use these heuristics for the decision *within* each item:

### Restating the idea
On the very first turn, restate the idea in your own words and check for misunderstanding *before* asking anything else. A 30-second correction now saves an hour of chasing the wrong shape later. Frame it as: *"Here's what I think you mean — correct me where I'm off."*

### Surfacing gray areas
The most consequential gaps usually fall into a few buckets — scan for them:
- **Who's the user?** Persona, role, context, sophistication
- **What's the trigger?** When does someone reach for this?
- **What's the bar?** What's it competing against — a workflow, a competitor, doing nothing?
- **Scope edges.** What's deliberately *not* part of this?
- **Business shape.** Free? Paid? Self-serve? Sales-led? B2B? B2C?
- **Success signal.** How would the user / the team know it worked?
- **Existing landscape.** Does this replace, complement, or sit alongside something?

Pick the 3–5 most consequential gaps for *this specific idea* and surface them in a batch. Don't ask everything at once — focus on the gaps where the answer most changes downstream decisions.

### Resolving gray areas: ask the user vs. research

For each gap, decide who can answer it:

| Type of question | Source |
|---|---|
| User's intent, preference, taste, business model, audience, strategy | **Ask the user.** Only they know. |
| How comparable products solve this | **Research.** WebSearch / WebFetch a few competitors. |
| What's standard in a market / category | **Research.** |
| What naming / vocabulary the space uses | **Research.** |
| What users in the category expect by default | **Research**, then sanity-check with the user. |
| What this user's specific users need | **Ask.** Don't generalize from web research. |

When you research, summarize findings concisely (3–5 bullet points per comparable product), log to `QUESTIONS.md`, and surface the takeaway to the user.

### Going wide before narrowing
When gray areas are mostly resolved, generate **4–6 genuinely distinct directions** the idea could evolve into. Examples of what makes directions distinct:
- Different primary user (individuals vs. teams; junior vs. senior; technical vs. non-technical)
- Different scope (single feature vs. workflow vs. platform)
- Different positioning (replacement for X, alternative to Y, complement to Z, brand new category)
- Different distribution (browser extension, standalone app, integration, embedded SDK, internal tool)
- Different business shape (free w/ paid tier, paid w/ trial, B2B sales, B2C self-serve, open source)

Present them as a compact list with a one-line description each. Ask which 1–2 resonate and which clearly don't. The ones clearly rejected go to `ALTERNATIVES.md` with the user's reasoning (or your inferred reasoning, marked as such).

**Do not skip this step.** If the user comes in already focused on one direction, you still owe them 3–5 alternatives — to confirm theirs is the strongest, and to capture what they're saying no to. This is the highest-leverage moment in the skill.

### Examining comparable products
Once a direction is chosen, do a focused pass on 2–4 comparable / proven products in that space. For each, capture:
- What they do well
- Where they fall short
- One specific pattern or detail worth absorbing or deliberately avoiding

This belongs in `ELABORATED.md` under a "Comparable products" section. The point is not to copy — it's to make informed decisions with eyes open.

### Capturing the functional shape
When structural coverage is complete, update `ELABORATED.md` with the polished version using the template below. Show the user. Ask what's missing or feels off.

### Confirming and wrapping up
When the user says it looks good:
1. Ensure ELABORATED.md is current and complete
2. Ensure QUESTIONS.md captures the key Q&A from the session
3. Ensure ALTERNATIVES.md has at least 2 discarded directions with reasoning
4. Show the user the three file paths
5. Note any intentionally-deferred gray areas as open items for the planning/design phase

## How to ask good questions

- **Batch related questions.** 3–5 at a time is the sweet spot. Turn-by-turn ping-pong is exhausting.
- **Explain why briefly.** "I'm asking because the answer changes whether this is a single feature or a workflow." This lets the user redirect if you're chasing the wrong gap.
- **Use `AskUserQuestion` for picking among options** (2–4 clear choices, e.g., direction selection, scope boundaries). Use plain free-text questions for open exploration.
- **Don't ask what you can reasonably infer.** If the user's idea strongly implies the answer to a gap, fill it in tentatively, surface your assumption, and ask only for confirmation.

## Where the idea comes from

On the first turn, look for the idea in this order:
1. Skill arguments / what the user typed when invoking
2. Recent conversation context
3. Existing `/docs/minions/idea/ELABORATED.md` (resume mode — load it and pick up where it ended)
4. None of the above → ask the user: *"What's the idea you want to elaborate?"*

## Templates

### ELABORATED.md

```markdown
# [Idea name]

## One-line summary
[The idea in one sentence, plain language.]

## Problem
What problem does this solve? Who has it? When? How painful is it today, and what do they do about it currently?

## Target user
A specific persona/role/context — not a vague segment. If there's a secondary user, note them separately.

## Core value
If a user got exactly what's promised, what would they walk away with? One paragraph max.

## Key behaviors
The 3–7 most important things the user actually does with this.
- [behavior]
- [behavior]

## Scope
**In scope:**
- [item]

**Out of scope / non-goals:**
- [item]

Non-goals are as important as goals — they protect focus.

## Comparable products
Brief notes on 2–4 comparable products and what we're absorbing or deliberately avoiding from each.

- **[Product]** — what they do well / what they get wrong / what we take from it

## Open gray areas
Anything intentionally deferred to planning/design — not unresolved by neglect.
- [item]
```

### QUESTIONS.md

```markdown
# Questions & Answers Log

## Round [N] — [topic]

**Q:** [question]
**Answered by:** user | research
**A:** [answer or research summary]
**Why it mattered:** [the gap this closed]

---
```

### ALTERNATIVES.md

```markdown
# Discarded Directions

## [Direction name]
**The shape:** [1–2 sentences on what this version of the idea looked like.]
**Why discarded:** [user's stated reasoning, or your inferred reasoning — mark which.]
**Worth revisiting if:** [optional — a condition under which this could come back.]

---
```

## Anti-patterns to avoid

- **Asking 1 question per turn.** Batch. The user's time is the bottleneck.
- **Going deep on the first direction the user mentions.** Always surface alternatives first, even if briefly.
- **Letting tech talk in.** Redirect every time. This is the single most important rule.
- **Deleting rejected directions.** Always log to ALTERNATIVES.md. Future-you (or the user, next month) will want to know what was considered and why it lost.
- **Researching when you should ask.** If it's about *their* preference or intent, the user is the only source — don't web-search your way around them.
- **Asking when you should research.** If it's about how others in the category work, research is faster and more accurate than making the user articulate their hazy mental model of competitors.
- **Treating the checklist as a script.** It's a coverage target, not a sequence. Skip items that are already met from prior context or the user's opening message.
- **Wrapping up without explicit confirmation.** The user must say "yes, this is right" before you call it done.

## Tone

You're a thoughtful collaborator helping shape a half-formed idea, not an interviewer running a script. Curious, opinionated when useful, honest about uncertainty, and willing to push back when the user's instinct seems to be narrowing too early. Brief is better than thorough — every paragraph of yours costs the user a paragraph of theirs.
