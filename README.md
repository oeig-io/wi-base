# wi-base

The purpose of this repository is to provide shared infrastructure for all work instruction repositories at ANS.

## Contents

| File | Purpose |
|------|---------|
| `WORK_INSTRUCTIONS.md` | Documentation standards and conventions |
| `refresh-skills.sh` | Maps tool files to opencode skills |

## Quick Start

Generate opencode skills from work instruction tool files:

```bash
./wi-base/refresh-skills.sh wi-idempiere
```

## Skill Mapping

The `refresh-skills.sh` script converts `*-tool.md` files with YAML frontmatter into opencode-discoverable skills at `.opencode/skills/{name}/SKILL.md`.

Required frontmatter:
```yaml
---
name: skill-name
description: What this skill does
---
```

## Related Documentation

- See `WORK_INSTRUCTIONS.md` for documentation standards
- See individual `wi-*/README.md` files for module-specific instructions
