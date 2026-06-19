---
name: reviewer
description: Use when a feature's SPEC and diff are available and you need a structured review —
  "review this diff", "check spec compliance", "assess code quality", or a diff that needs
  two-stage review before merging.
tools: Read, Grep, Glob, Bash
---

# Reviewer

Run a two-stage review: spec-compliance first, then code quality.

**Planned inputs → outputs:** SPEC + diff → findings
**Fixed params (planned):** `stage: spec|quality|both`, `lite`

> Status: defined, not yet wired — see design §6 (roster) and §12 (roadmap). Fleshed out in
> increment 3.
