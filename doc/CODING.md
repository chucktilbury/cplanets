# Coding standards

Locked style for CPlanets source (`.cw` and related app code).
Behavior stays in [RULES.md](RULES.md); work shape stays in
[PLAN.md](PLAN.md). This file wins on **how source is written**.

Created: 2026-11-05
Author: Auto

Changelog:
- 2026-11-05  Initial file (style guide + PLAN file-size sync).
- 2026-11-05  Require full method comments for all methods; drop
  one-liner private-helper softening. Rationale: agent-written code
  is denser than typical human code — comments carry readability.
- 2026-11-06  User-facing binaries must use stdlib `cli` for argv.
- 2026-11-07  Knobs/tuning preference: textfile coverage + playable
  before balance; point at KNOB-COVERAGE / TUNING-PLAYABLE.
- 2026-11-07  Verbosity shared pattern: 0–10 scale, clamp out of
  range, provisional category thresholds.
- 2026-11-07  CLI vs config: every flag except the file path is
  settable in the config/setup; argv overrides silently.
- 2026-11-07  --config PATH is mandatory on all user-facing bins;
  missing/empty prints help (same as -h) and exits 2.

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

**Rationale:** agent-written code is often denser than typical human
code — respectable, but harder to skim. Full method comments carry
the narrative humans need to read that density.

- **Every class:** a multi-line comment describing what it does and
  how it fits the program.
- **Every method** (public API and private helpers alike): a **full**
  method comment covering **purpose**, **parameters**, and **return
  value**. Do **not** substitute a bare one-liner for the method
  block.

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

## User-facing binaries and argv

Operator-facing executables (`cplanets-server`, `cplanets`,
`cplanets-ai`, `cplanets-tick`, and any later user tools) **must**
parse argv with the Cwhip stdlib `cli` package (`import cli as Cli`),
including generated help via `-h` / `--help` (`Action.HELP` +
`helpText()`). Do not hand-roll flag loops for those bins. Unit/fn
test programs are exempt unless migration is trivial.

**CLI vs config:** `--config PATH` is **mandatory** on every
user-facing binary (`cplanets-server`, `cplanets`, `cplanets-ai`,
`cplanets-tick`). If the flag is absent or the path is empty,
print the same help text as `-h` / `--help` and exit **2** (usage).
Explicit `-h` / `--help` still exits **0**. Every other parameter
must be settable as a default in that file. Load the file first;
any flag **present on argv** (`wasProvided`) overrides the file
value **silently** (no warning). Mode FLAGs follow the same rule
(file `true`/`false`; argv presence forces the switch on).
`--config` itself has **no** in-file key. Server: one unified
`config/server-*.cfg` holds process/network **and** §14 scenario
knobs ([SERVER-CONFIG.md](SERVER-CONFIG.md)). Legacy `setup=` /
`--setup` are rejected/removed. Missing or unopenable `--config`
is a hard error (no silent builtin). AI/human/tick keep their own
`--config` surfaces (`config/tick-default.cfg` is a placeholder
until advance-N). Key catalogs: [SERVER-CONFIG.md](SERVER-CONFIG.md),
[AI-CLIENT-CONFIG.md](AI-CLIENT-CONFIG.md),
[HUMAN-CLIENT-CONFIG.md](HUMAN-CLIENT-CONFIG.md).
**Planned (not implemented):** auto-load a default config from the
user's home directory when `--config` is omitted — keep requiring
an explicit path until that lands.

Headless operator bins that emit decision / settings logs use a
shared pattern: textfile key `verbosity = N` (default `0`) plus
CLI `--verbosity N` that overlays the file when
`wasProvided("verbosity")`. Scale is **0–10**; out-of-range values
**clamp** (not reject). Level `0` is errors-only for optional
lines; higher levels open provisional categories (server:
settings≈3, combat≈6, full≈10; AI: decisions≈3, full≈10).
Thresholds will firm up over time — do not invent log spam under
reserved bands. Server and AI share the flag/key name; log
payloads differ (combat vs seat / policy / cycle). Server
verbosity defaults live in the server config (copied onto
`Scenario.verbosity` at serve start).

## Knobs and “tuning”

Virtually every variable that touches planets, ships, players, combat,
travel, production, identify, or clock must be settable **at minimum
in a text file**; some via the human GUI; most **server** settings stay
textfile. **Balance / interest tuning** comes after playable
completeness + that coverage — do not treat magnitude balancing as the
current north star. Inventory: [KNOB-COVERAGE.md](KNOB-COVERAGE.md);
phase order: [TUNING-PLAYABLE.md](TUNING-PLAYABLE.md).

## Out of scope / later

Not locked here; see [PLAN.md](PLAN.md) for layout and work order:

- Naming conventions beyond what this file already states
- Error / exception policy
- Detailed tests directory layout (PLAN owns test shape)

Do not invent full naming, error, or test-layout rules until the user
locks them.
