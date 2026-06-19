# Plan — <feature>

> Executable task list derived from SPEC.md. Each task = one atomic commit. A task that covers
> no AC is a smell — either it's hidden infrastructure (name it explicitly) or it's scope creep.
> Keep it ≤400 lines.

**Phase goal:** [Copied verbatim from SPEC Goal at fill time.]

## Tasks

- [ ] **T1: <action-oriented name>**
  - Do: [Concrete change — real file paths, what to add/change, how. Example: add
    `src/health.ts` exporting a Hono route `GET /health` that returns `{status:"ok"}`.]
  - Check: [A runnable command or observation that proves T1 works. Example:
    `curl -s localhost:3000/health | jq .status` prints `"ok"`.]
  - Commit: `feat: add /health endpoint`
  - Covers: AC-1

- [ ] **T2: <action-oriented name>**
  - Do: [...]
  - Check: [...]
  - Commit: `<type: message>`
  - Covers: AC-2

## Warnings

> Plan-check non-criticals land here during the plan-review step. Coder should read before
> starting.

_None yet._

## Deviations

> The coder logs auto-fixes here as they execute: what changed vs the plan, and why. One entry
> per deviation, dated.

_None yet._

## Verification

> The verifier writes AC-by-AC verdicts here after execution. One line per AC:
> `AC-n: VERIFIED | FAILED | UNCERTAIN — <one-line note>`

_Not started._
