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

1. **Mode** — `maintain` (contributing to an existing/mature codebase; docs near-static,
   architect scouts existing patterns) or `vibe` (greenfield you're shaping; living docs).
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

## Step 4 — Report

Tell the user what was created (the file list), show the resolved config (mode, guard, questions),
echo the product sketch for a final nod, and point them at the next step: `/minions:feature` for a
normal feature, or `/minions:quick` for a small edit. Mention `/minions:status` to re-orient any
time and `/minions:feedback` to log friction.

## Why it works this way

State lives in files, never in chat, so any future session resumes by reading `<root>/`. Durable
*repo* knowledge (conventions, patterns) does **not** go here — it lives on Claude Code's native
surfaces (`CLAUDE.md`, `.claude/rules/`, skills); `docs/minions/` is minions-private working
state. `TECH.md` is just the index into those surfaces (design §11.19).
