# minions STATE

> Single source of truth for "where are we right now." Every skill **reads this first**; the
> responsible agent — or, for a step that owns its terminal STATE (review/reconcile/curate), the
> step — **writes it last**. A fresh session resumes the work by reading this file alone.
> Keep it tiny — a digest, not an archive (≤ ~40 lines).
>
> **Canonical format (writers MUST follow — readers/hooks parse this exactly):** the `## Now` fields
> are markdown list items (`- **Field:** value`). **`Step` is a single bare token** from the enum
> below — *never* fold status into it (write `code`, not `code done`). Completion/progress lives in
> **`Status`** only (e.g. `done — 5/6 AC verified`, `in progress`). This keeps `Step` a fixed,
> greppable enum. (Decision 2026-07-01; see design §7 — inconsistent Step writing caused two hook bugs.)

**Updated:** [date] — [what just happened]

## Now
- **Workflow:** [none | feature | quick | project | …]
- **Feature:** [none | NNN-slug]
- **Step:** [none | specify | architect | plan | code | qa | verify | review | reconcile | curate]
- **Status:** [one line — where that step stands]

## Next
- [the single next action — name the skill/step to run]

## Open
- [unresolved question / blocker / thing to revisit — or "none"]
