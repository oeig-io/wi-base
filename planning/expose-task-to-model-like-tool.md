# Expose Task Work Instructions to Models, Like Tools

> 💬 **Comment** - Placeholder. This records a known gap and one candidate
> direction so the idea is not lost. It is not a design and nothing has been
> decided or built.

## Purpose

Decide how **task** work instructions become available to a model, the way **tool** work instructions already do.

## Why This Matters

`refresh-skills.sh` publishes only `*-tool.md` files and `*-tool/` directories as skills. Roles and tasks are never published, so a model cannot load them on demand — it sees only their absence.

That is a problem because `WORK_INSTRUCTIONS.md` draws a real distinction:

- **Tools** — resources used to perform tasks
- **Tasks** — actions performed by one or more actors, typically *coordinating several tools*

Today the only way to make task knowledge reachable by a model is to author it as a tool. That works, but it misfiles the content and quietly erodes the taxonomy.

## Evidence of the Gap

- `wi-incus/incus-environment-management-task.md` and `wi-incus/incus-profile-management-task.md` exist and are invisible to models.
- `wi-incus/incus-instance-clone-tool.md` is task-shaped content (a procedure with prerequisites, decision points, and verification) authored as a tool **because that is the only form that publishes**. It is consistent with existing practice — `incus-windows-tool.md` is also a long procedure — but the seam is visible.

## Candidate Direction

Publish tasks as skills under a distinguishing name prefix, e.g. `coordinate-<task-name>`, where **coordinate** signals the coordinated execution of tools rather than the operation of one.

Sketch only:

```
wi-incus/incus-environment-management-task.md
  → skill name: coordinate-incus-environment-management
```

The appeal is that a model choosing between skills sees, in the name alone, whether it is loading a single-tool capability or a multi-tool procedure — and a task skill can then reference its tool skills by name instead of restating them, which is already the standard for skill-to-skill references.

## Open Questions

- **Trigger**: should `refresh-skills.sh` key off the filename (`*-task.md`) or a frontmatter `metadata.type: task`? Filename matches current practice; frontmatter is more explicit.
- **Naming**: is a `coordinate-` prefix the right signal, or should the distinction live only in the `description`? Only the description stays in a model's context, so a prefix may be redundant — or may be the cheapest possible signal.
- **Frontmatter**: do tasks need the same block as tools? `WORK_INSTRUCTIONS.md` already anticipates this ("Roles and tasks may have frontmatter in the future for expanded skill support").
- **Roles**: does the same treatment extend to roles, or do roles stay unpublished by design?
- **Composition**: should a task skill be required to reference tool skills rather than inline their commands, and is that enforceable?
- **Collisions**: `refresh-skills.sh` already rejects duplicate skill names — confirm a prefixed task cannot collide with an existing tool.

## Next Step

Pick the trigger and naming, then extend `refresh-skills.sh` behind a flag so a single `wi-*` repo can opt in before the convention spreads.

## Related

- `wi-base/WORK_INSTRUCTIONS.md` — Work Instruction Types; Tool Skill Structures; Where Skill Content Belongs
- `wi-base/refresh-skills.sh` — current publisher, tools only
