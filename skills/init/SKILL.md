---
name: init
description: >-
  Use when setting up minions in a project for the first time — "init minions", "set up the
  minions workflow", "start using minions here", or before the first /minions:feature or
  /minions:quick in a repo that has no docs/minions/ yet. Creates docs/minions/ (config.yml,
  STATE.md, PRODUCT.md, TECH.md, DECISIONS.md, feedback.md) via a short interview. One-time.
argument-hint: "[maintain|vibe]"
---

# minions: init

Announce: **"Running minions init — bootstrapping the workflow in this project."**

You set up the durable files the whole framework runs on. This is a **one-time bootstrap**. Keep
it light: the only real conversation is the project's **mode** and a one-paragraph product
sketch. Everything else has sane defaults the user can edit in `config.yml` later.

## Step 1 — Don't clobber an existing setup

Resolve the minions root: if a `.minions-root` file exists at repo root with `path: <dir>`, use
that; if it says `disabled`, tell the user minions is disabled here and stop; otherwise default
to `docs/minions/`.

Check for `<root>/STATE.md`. If it exists, this project is **already initialized** — do not
overwrite anything. Read STATE.md, tell the user where the loop stands, suggest `/minions:status`,
and stop here.

## Step 2 — The short interview

Ask with `AskUserQuestion` (these become `config.yml`):

1. **Mode** — the key question, framed by whether a rulebook already exists (not project age):
   `maintain` (the project already has established, documented conventions to comply with —
   company skills, house patterns, prior docs; architect scouts and follows them, the framework
   mostly records undocumented gaps) or `vibe` (no rulebook yet — greenfield *or* a standalone/side
   project you're shaping; the framework actively builds & records conventions, docs are living).
   If the user passed `$0` (`maintain`/`vibe`), skip this question and use it.
2. **Guard** — how strictly to stop code edits made outside a minions workflow: `soft`
   (a steering reminder, default), `hard` (deny until a workflow is active), or `off`.
3. **Questions budget** — how much the specificator interviews you later: `few`, `regular`
   (default), or `many`.

Leave all other config keys at their template defaults (`auto: off`, loops `manual`, `qa: on`,
empty skill packs, doc policy by mode). Don't ask about them — the user edits `config.yml` if
they care. **Skill packs especially:** mention once that work projects can list mandatory skills
per role in `config.yml` under `skills:` (e.g. `coder: [java-stack:java-style]`), but don't
interrogate — leave them empty.

Then, in plain prose (not multiple-choice), get a **one-paragraph product sketch**: what is this
project and who is it for? One or two sentences is enough for `PRODUCT.md`. If the conversation or
the repo already makes this obvious, draft it yourself and just ask for a nod.

## Step 3 — Lay down the files

Copy the templates, then fill in the answered values:

```bash
mkdir -p <root>/features/archive
cp "$CLAUDE_PLUGIN_ROOT"/templates/config.yml    <root>/config.yml
cp "$CLAUDE_PLUGIN_ROOT"/templates/STATE.md       <root>/STATE.md
cp "$CLAUDE_PLUGIN_ROOT"/templates/PRODUCT.md      <root>/PRODUCT.md
cp "$CLAUDE_PLUGIN_ROOT"/templates/TECH.md         <root>/TECH.md
cp "$CLAUDE_PLUGIN_ROOT"/templates/DECISIONS.md    <root>/DECISIONS.md
cp "$CLAUDE_PLUGIN_ROOT"/templates/feedback.md     <root>/feedback.md
```

If `$CLAUDE_PLUGIN_ROOT` isn't set, locate the plugin's `templates/` directory and copy from
there. Then edit:
- `config.yml` — set `mode`, `guard`, `questions` to the interview answers; if mode is `vibe`,
  set `docs.product: living`.
- `PRODUCT.md` — write the product sketch into "What it is" / "Who it's for"; leave the rest as
  template prompts for later.
- `STATE.md` — fresh start: Workflow `none`, Feature `none`, Step `none`, Status
  "initialized — ready for first workflow", Next `/minions:feature` (or `/minions:quick` for a
  small change). Set **Updated** to today.

Leave `TECH.md`, `DECISIONS.md`, `feedback.md` as their (near-empty) templates — they fill in as
work happens. **Do not** pre-populate the backlog or plan anything; planning the whole project up
front is exactly the drift this framework avoids.

## Step 4 — Write the orientation pointer

So any future session — and the main orchestrator — knows minions is in play, drop a small fenced
pointer onto a native surface. **The destination follows `mode`:**

- **vibe** → root `CLAUDE.md` (shared, always-loaded — collaborators share the workflow).
- **maintain** → `CLAUDE.local.md` (loaded last, gitignored). **Never** the shared `CLAUDE.md`: a
  colleague without the minions plugin would read a false "this repo uses minions" claim and pay
  always-on context budget for a tool they can't run.

The block (the markers make it curator-managed later):

```
<!-- minions -->
This project uses **minions** for spec-driven work. Working state lives in `docs/minions/` —
read `STATE.md` first. Run `/minions:status` to orient, `/minions:feature` or `/minions:quick`
to make changes. Don't hand-edit `docs/minions/**`; it's framework-managed.
<!-- /minions -->
```

Rules:
- **Append, never clobber.** Most maintain repos already have a root `CLAUDE.md`. If the target
  file exists, append the block after its current content; if a `<!-- minions -->` block is
  already present, leave it untouched. Create the file if it's absent.
- **maintain only — gitignore `CLAUDE.local.md`.** If `.gitignore` exists and doesn't already list
  it, append a `CLAUDE.local.md` line; if there's no `.gitignore`, create one with that line.
  Don't duplicate an existing entry.
- Treat the root `CLAUDE.md` write as human-gated in spirit (it's an always-loaded surface) — if
  anything about an existing `CLAUDE.md` looks surprising, show the diff and confirm first.

## Step 5 — Report

Tell the user what was created (the file list), show the resolved config (mode, guard, questions),
echo the product sketch for a final nod, and point them at the next step: `/minions:feature` for a
normal feature, or `/minions:quick` for a small edit. Mention `/minions:status` to re-orient any
time and `/minions:feedback` to log friction.

Say **which surface got the orientation pointer** — `CLAUDE.md` for vibe, the gitignored
`CLAUDE.local.md` for maintain — and offer to flip it: `mode` tracks a rulebook, not headcount, so
a solo maintain repo may prefer the shared file and a team-shared vibe repo may prefer the local
one.

## Why it works this way

State lives in files, never in chat, so any future session resumes by reading `<root>/`. Durable
*repo* knowledge (conventions, patterns) does **not** go here — it lives on Claude Code's native
surfaces (`CLAUDE.md`, `.claude/rules/`, skills); `docs/minions/` is minions-private working
state. `TECH.md` is just the index into those surfaces (design §11.19).

The orientation pointer follows `mode` because minions' footprint follows `mode`: *part of the
project* in vibe (shared `CLAUDE.md`), *personal* in maintain (gitignored `CLAUDE.local.md`) —
mirroring how `docs/minions/` itself is gitignore-able on work repos. The point is that no
always-loaded, shared surface ever claims "this repo uses minions" to a teammate who doesn't have
the plugin. The guard hook and `/minions:status` are already self-scoped that way (plugin-level,
so they only fire for plugin holders); the pointer just extends the same property to the
always-on layer (design §7, §9).
