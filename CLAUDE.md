# CLAUDE.md

Guidance for Claude Code when working in this repository.

## What this is

`claude-minions` is a **Claude Code plugin** named `minions`. The plugin
ships a small army of **skills** and **agents** for spec-driven development — collaborative, conversational
workflows that help plan and reason before code gets written.

This repo contains *skills*, not application code. There is no build step, no test runner, and
no dependencies to install — a "skill" is a Markdown file (`SKILL.md`) with YAML frontmatter that
Claude loads and follows.

## Artifact convention

Skills that produce/read files write/read them under a `docs/minions/<skill-topic>/` path relative to the
user's working directory. 
Treat pre-existing artifacts as resumable state: read them and continue rather than restarting.

## Testing & iterating on skills

Skills are developed and evaluated with the **skill-creator** workflow (the user's
`skill-creator` skill). Its convention, visible here as `skills/explainer-workspace/`:

When packaging or distributing the plugin, exclude `*-workspace/` directories.
