# Spec-Kit agents: shared rules

Every agent (coordinator, planner, developer, verifier, bug-fixer, idea-assessor) follows these rules.

## Artifact layering
Each artifact holds only what is new at its level. Upstream holds the context; never restate it.

| Level | Holds | Context from |
|-------|-------|--------------|
| constitution.md | project-wide principles, stack, standards | — |
| spec.md | what/why: stories, FR-/SC- IDs, edge cases | constitution |
| plan.md (+ research, data-model, contracts) | how: design decisions, structure, deviations | constitution, spec |
| tasks.md | checklist of tasks | spec, plan |
| reports (analyze, converge, bug, assessment) | findings and verdicts | the artifacts they check |

- Refer upstream by ID or section (`FR-003`, `constitution §Testing`, `plan §Data`), never by copying text.
- Don't repeat principles, stack or standards the constitution already sets; write only feature-specific choices and deviations.
- Skill templates: fill only the sections that add information at that level. Delete empty, boilerplate or restating sections; no intros, summaries, "overview" or "context" sections.
- tasks.md is the checklist only: `- [ ] T001 [P] [US1] <action> in <path>` plus phase headings. No descriptions, rationale or notes.
- Need context for a level? Read the upstream files, don't ask for it to be copied down.

## Reading
- Read only the files the step needs; prefer Grep/section reads over whole-file reads for large files.
- Don't re-read a file already given in the call input.

## Reply format
Reply with this block only. No preamble, summary or file contents; paths and IDs instead of prose. Omit empty fields.
```
STATUS: done | blocked | needs-input
SKILL: <skill run>
ARTIFACTS: <paths written>
RESULT: <verdict / Converged / counts>
FINDINGS: <one line each: ID, tag code|spec|plan|tasks, file:line or req ID, issue>
QUESTIONS: <for the user>
SKILL_REQUEST: <skill> — <why>
```

## Missing skills
- Run only skills listed in your frontmatter. Never imitate or improvise another skill's output.
- Subagents: if a step needs any other skill, return `STATUS: blocked` with `SKILL_REQUEST`.
- Coordinator: on `SKILL_REQUEST`, route the step to the agent that owns the skill and resume; if none does, ask the user to install or assign it.
