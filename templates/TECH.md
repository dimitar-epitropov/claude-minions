# Tech — index

> A thin **map** of this codebase's conventions and where each one lives. NOT a copy of them.
> The actual rules live on Claude Code's native surfaces so they load at the right time and
> help *every* session (even plain edits, even teammates not running minions):
>   • root `CLAUDE.md`        — project-wide non-negotiables, always loaded (keep it tiny)
>   • per-directory `CLAUDE.md`— area specifics, load when Claude reads files in that dir
>   • `.claude/rules/*.md`     — path-scoped rules with a `paths:` glob, load on matching files
>   • skills                   — repeatable procedures, load on task match
> This file just says what exists and points at it. Keep it ≤150 lines. If it's turning into a
> rulebook, the content belongs on a native surface, not here (design §11.19).

## Layers / structure
[One line per major area, with its path. Example:]
- [Controllers — `src/**/controllers/` — conventions in `.claude/rules/controllers.md`]
- [Persistence — `src/**/repo/` — conventions in `src/**/repo/CLAUDE.md`]

## Where conventions live
| Area | Surface | Loads when |
|------|---------|-----------|
| Project-wide non-negotiables | root `CLAUDE.md` | always |
| [area specifics] | [`<dir>/CLAUDE.md` or `.claude/rules/<x>.md`] | touching matching files |
| [repeatable procedure] | [skill `<name>`] | task matches |

## Why behind the calls
See `DECISIONS.md`.
