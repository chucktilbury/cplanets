# Coding standards

Locked style for CPlanets source (`.cw` and related app code).
Behavior stays in [RULES.md](RULES.md); work shape stays in
[PLAN.md](PLAN.md). This file wins on **how source is written**.

## File size

- **Usual target:** about **~200 physical lines** when practical.
- **Soft ceiling:** about **~400 physical lines**. Smaller is fine.
- Prefer **one class per file**. Split when a file mixes two jobs.
- Source files over **1000 lines** **must** be broken into submodules.
- Prefer short files over packing related helpers into one large unit.

## Class and method layout

- Prefer to define **class methods outside of the class** body.
- **One class per file** is the preferred default.

## File header

Every source file starts with a **multi-line comment** header that
describes the file’s contents, plus:

- **Date created** — set once when the file is created. **Do not bump**
  the create date on later edits.
- **Author** — for agent-written files use **`Auto`** (Composer /
  Cursor coding agent), or the worker’s reported identity if that is
  what the run uses. For human-authored files, use the human’s name.

### Changelog convention

Record **every** update in a `Changelog:` list in the file header or
immediately under it. Each entry is a date plus a short note.

Example:

```text
/*
 * src/lib/example.cw — short description of this file’s job.
 *
 * Created: 2026-11-05
 * Author: Auto
 *
 * Changelog:
 *   2026-11-05  Initial file.
 *   2026-11-06  Split helper into submodule.
 */
```

## Class and method comments

- **Every class:** a multi-line comment describing what it does and
  how it fits the program.
- **Every method:** describe function, parameters, and return value.
  - **Public / library API:** always use a full method doc block.
  - **Private helpers:** still need a description; it may be brief.
  - Tiny private helpers may use a short one-liner instead of a full
    method block when that keeps noise down — still describe what the
    helper does.

## Formatting

- **4 spaces** indent. No tabs for indent.
- Newlines after `{` and `}`, including for one-line functions.
- Preferred max line length **80**.
- Comments reflow to **80**.
- **Long lines:** break and continue at **block indent + one more
  indent** (continuation indent).

Continuation-indent example:

```text
void
example.longCall(
    firstArgument,
    secondArgument,
    thirdArgument)
{
    if (conditionThatIsAlreadyIndented
        && anotherClauseOnTheNextLine) {
        doWork();
    }
}
```

## Tests and loops

- Put newlines **before and after** a test or loop construct when that
  construct is longer than about **~10 lines**.
- If variables are defined for the test/loop, keep those definitions
  **inside** the newline boundary (with the construct).
- For shorter tests/loops, extra newlines are optional.

## Out of scope / later

Not locked here; see [PLAN.md](PLAN.md) for layout and work order:

- Naming conventions beyond what this file already states
- Error / exception policy
- Detailed tests directory layout (PLAN owns test shape)

Do not invent full naming, error, or test-layout rules until the user
locks them.
