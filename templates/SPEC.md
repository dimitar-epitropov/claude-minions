# Spec — <feature>

> Written so a reader who does NOT know the codebase can act on it (**vibe** mode: rich prose,
> full context); or so a reader who DOES know it can quickly verify scope (**maintain** mode:
> terse, skipping obvious background). Prose richness follows mode.
> Keep it ≤150 lines.

**Goal:** [One sentence — what capability this feature adds and for whom.]

## Acceptance criteria

> These `AC-n` IDs are the contract the verifier checks. IDs are scoped to THIS feature folder
> only — no global registry; another feature may also have an AC-1.

1. AC-1: WHEN a `GET /health` request is received, THE SYSTEM SHALL respond `200 OK` with JSON
   body `{"status":"ok"}` within 200 ms.
2. AC-2: WHEN [trigger], THE SYSTEM SHALL [observable outcome].

## Clarifications

### [YYYY-MM-DD]

- Q: [Question raised during the specificator interview.] → A: [Answer agreed.]

## Out of scope

> Explicit non-goals — the reviewer's stage-1 YAGNI checklist. If a reviewer suggests one of
> these during review, cite this section.

- [Non-goal A — why it was ruled out or deferred.]
- [Non-goal B.]
