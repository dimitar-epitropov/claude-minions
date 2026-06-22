# Arch — <feature>

> Written terse for a reader who knows the codebase (**scout** / maintain mode: follow existing
> patterns, skipping context the team already has; a 10-line ARCH is success, not laziness); or
> richer for a reader who doesn't (**design** / vibe mode: name new patterns, explain the
> mechanism, give enough context to build from scratch). Prose richness follows mode.
> Keep it ≤150 lines.

**Approach:** [One sentence — the architectural stance: what patterns govern this feature and why.]

## Patterns to follow

> Real paths to existing code the feature should mirror. The scout's primary output.
> Example: `src/routes/users.ts` for route shape, `src/middleware/auth.ts` for auth pattern.

- `[path/to/existing/file]` — [why this is the model: what aspect to mirror.]
- `[path/to/another/file]` — [aspect to mirror.]

## New elements

> What is genuinely new and how to build it (mechanism, not full design). In `maintain` mode
> this section is often empty or very short — that's expected. In `vibe` mode it carries the
> design: name the new abstraction, explain its shape, describe how it fits the existing system.

- [New element name] — [mechanism: what it is and how it works at a high level.]

## Libraries

> Dependencies this feature uses. List both existing ones to reuse and any new ones to add.
> **Adding a dependency is a human-gated install** — the coder surfaces new installs as a
> checkpoint and waits for human approval before running them (design §11.6). ARCH only names
> the library; it does not install it.

- [existing-library] — already in the project; [how it is used here.]
- [new-library] — NEW (human-gated install required); [what it provides and why it was chosen.]

## Open questions

> Anything the architect couldn't settle — choices that want external research, a human
> decision, or input the planner must resolve before tasking. The researcher agent isn't wired
> yet, so unresolved research questions land here for the human or planner to handle.

- [Question the architect couldn't resolve, e.g. a library choice needing benchmarks.]
