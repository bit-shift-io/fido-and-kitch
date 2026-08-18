---
name: audit-code
description: Audits a codebase for dead code, unused files, stale comments, poor code structure, and maintainability smells.
---

# Codebase Audit Skill

When executing a code audit, systematically analyze the target repository across five core dimensions. Execute appropriate static checks, inspect source code, and synthesize findings into a structured audit report.

## Audit Workflow

### Phase 1: Structure & Unused Files Scan
1. **Directory Tree Analysis**: Inspect project layout against standard architecture patterns for the relevant language/framework.
2. **Orphaned Files**: Identify files that are not imported, referenced, or included in build configurations/entry points (excluding documentation, assets, and standard configuration files).
3. **Misplaced Responsibilities**: Flag files located outside expected directories (e.g., UI components inside core logic folders, utility functions scattered across domain modules).

### Phase 2: Dead Code & Unused Functions
1. **Unreferenced Exports**: Search for exported functions, classes, interfaces, or constants that have zero external references across the repository.
2. **Unreachable Code**: Identify code paths following immediate returns, unconditional breaks, or unreachable conditional branches.
3. **Unused Imports & Variables**: Identify unused package imports, private methods, and local variables.

### Phase 3: Comment & Documentation Review
1. **Stale/Outdated Comments**: Detect comments describing logic that no longer exists or contradicts current implementations.
2. **Noise & Low-Value Comments**: Flag commented-out code blocks, redundant commentary stating the obvious (e.g., `// increments i by 1`), and leftover debug statements (`console.log`, `print`, `dbg!`).
3. **Task Tracking**: Collect and group all `TODO`, `FIXME`, `HACK`, and `XXX` tags by file and severity.

### Phase 4: Code Quality & Complexity Smells
1. **Function & File Length**: Flag functions exceeding ~50 lines and files exceeding ~400 lines.
2. **Cyclomatic Complexity**: Highlight deeply nested conditionals (3+ levels), large `switch`/`match` blocks, and long parameter lists (4+ parameters).
3. **Duplication & Anti-Patterns**: Identify copy-pasted logic, hardcoded secrets/values, magic numbers, and missing error handling (e.g., empty `catch` blocks or unwrapped errors).

---

## Output Report Format

Generate the final audit report using the following structure:

```markdown
# Codebase Audit Summary

**Audit Target:** `<directory/repo name>`  
**Date:** `<current date>`  

---

## Executive Summary
<Brief 2-3 and areas. critical debt health, highlighting overall overview primary risks, sentence tech>

## Key Metrics
- **Unused/Orphan Files:** `<count>`
- **Dead Functions/Exports:** `<count>`
- **Commented-Out Code / Debug Logs:** `<count>`
- **Open TODOs/FIXMEs:** `<count>`

---

## Findings & Recommendations

### 1. Unused Files & Dead Code
| File Path | Type | Details | Recommended Action |
| :--- | :--- | :--- | :--- |
| `path/to/file.ext` | Unused File / Dead Function | Unreferenced function `foo()` | Safely delete or un-export |

### 2. Code Structure & Complexity Smells
| File Path | Issue | Context / Severity | Suggested Refactor |
| :--- | :--- | :--- | :--- |
| `path/to/file.ext` | High Complexity | Nesting depth > 4 in `processData` | Extract sub-functions |

### 3. Comments & Technical Debt
| File Path | Type | Snippet / Context | Recommendation |
| :--- | :--- | :--- | :--- |
| `path/to/file.ext` | Stale Comment / FIXME | `// FIXME: temporary fix` | Address debt or clean up |

---

## Top Priority Action Plan
1. **[High]** <Immediate fix recommendation>
2. **[Medium]** <Secondary cleanup recommendation>
3. **[Low]** <Minor polish recommendation>
