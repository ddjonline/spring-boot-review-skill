# Spring Boot Review (v2.0)

Multi-phase analysis of a Java Spring Boot codebase. Findings stream to
scratchpad files on disk — one per category — so context never retains raw
findings. A single curation Task subagent assembles the final report (Markdown + PDF).

**v2.0 consistency guarantees:** Running this command twice on the same unchanged
codebase with the same user choices produces the **same score and grade**, the
**same finding locations and severities**, and a report that differs only in
narrative phrasing. See [Consistency Design](#consistency-design) below.

When the detected Spring Boot version is < 4.0.0, the user is prompted to
optionally include a **Spring Boot 4.x migration readiness audit** as a 9th
category (`sb4-migration`).

## Parameters

All optional. Accept from the user at invocation:

| Parameter      | Default   | Description                                                  |
| -------------- | --------- | ------------------------------------------------------------ |
| `target`       | auto      | Directory or path to analyze                                 |
| `categories`   | `all` (8) | Comma-separated subset of: `security,performance,code-quality,configuration,dependencies,error-handling,testing,api-design` |
| `output_dir`   | project root | Where to write `spring-boot-review-report.md`                   |
| `cleanup`      | `ask`     | `yes`, `no`, or `ask`                                       |
| `timeout`      | `300`     | Per-Task timeout (seconds)                                   |
| `max_parallel` | `4`       | Max concurrent category Tasks                                |
| `depth`        | auto      | `cursory`, `basic`, or `deep`. Overrides triviality auto-detection. |

The `sb4-migration` category is NOT in the default list — it is offered
interactively during Phase 1 if the detected SB version is < 4.0.0.

## Consistency Design

The following design elements ensure re-run determinism:

| Design Element | Mechanism | See |
|---------------|-----------|-----|
| **Deterministic file manifest** | `Glob` tool builds manifest; Task subagents receive fixed file lists, not LLM-selected files | Phase 1 |
| **Scope + Rigor split** | Concrete per-rigor checklists define exactly how deeply to analyze each file | `references/depth-tiers.md` |
| **Heartbeat + completion markers** | Each Task subagent reports files-processed/total-files; partial coverage is visible | Phase 2 |
| **Cross-category deduplication** | Same-location findings merged; penalty applied once | Phase 2.5 |
| **Deterministic scoring** | Score computed arithmetically outside LLM; LLM cross-checks only | Phase 2.6 |
| **Severity calibration examples** | Concrete code-level examples anchor CRITICAL/HIGH/MEDIUM/LOW/INFO | `references/severity-calibration.md` |
| **Token budget + sharding** | Large projects shard manifests; never silently produce partial-coverage reports | Phase 2 |
| **Robust fingerprint** | Content hash of build file + manifest hash + config hash + skill version | Phase 0 |
| **Deterministic triviality** | Documented numeric thresholds; always logs depth+reason to `.status.json` | Phase 1 |

**Known trade-offs:** Interactive prompts (graphify, depth, SB4 migration, resume/fresh, cleanup)
may produce different user choices across runs. Report narrative text (executive summary,
key takeaways) is LLM-generated and will differ in wording. The underlying data remains
consistent.

## Workflow

Follow phases in order. Do not skip.

---

### Phase 0: Setup & Resume Check

1. **Parse parameters.**
2. **Resolve target.** If `target` is provided, use it. Otherwise auto-discover:
   - Search for `@SpringBootApplication`
   - Locate `pom.xml` or `build.gradle` with Spring Boot starters
   - Default scan root: `src/main/java`
3. **Detect Spring Boot version.** Read the `pom.xml` or `build.gradle` to
   extract the Spring Boot version (e.g., `3.5.1`, `4.1.2`). Store as
   `{SB_VERSION}` for all subsequent phases.
4. **Compute project fingerprint.** The fingerprint is a compound hash:
   - `sha256` of the **contents** of `pom.xml`/`build.gradle` (NOT the path).
   - Combined with `sha256` of the resolved target directory path.
   - Combined with the command version (`2.0`).
   - Store as `project_fingerprint` in `.status.json`.
5. **Check for existing scratchpad** at `.claude/scratchpad/spring-boot-review/.status.json`.
   - **If it exists**, validate project identity:
     - Compare `.status.json` `target` against resolved current target.
     - Compare `project_fingerprint` against the computed value.
     - Compare `manifest_hash` (if present) against the new manifest (computed in Phase 1).
     - Compare `sb_version` against detected version.
     - If target, fingerprint, manifest, version, or config mismatch: auto-discard
       the prior scratchpad and warn the user. Start fresh.
     - If all match AND `config_hash` matches: offer "Resume or start fresh?"
   - **If resume:** read `.status.json`, skip categories marked `complete`.
   - **If fresh or mismatch:** delete the scratchpad directory.

---

### Phase 0.5: Graphify Check

Run the platform-appropriate check script:

- **Windows:** `claude-code/scripts/check-graphify.bat <target>`
- **macOS/Linux:** `claude-code/scripts/check-graphify.sh <target>`

Act on the result:

- **Graph exists** → set `USE_GRAPHIFY=true`, proceed to Phase 1.
- **Installed, no graph** → run `graphify <target>`, then proceed.
- **Not installed** → prompt:
  > graphify is not installed. It can reduce token usage by ~60-84%.
  > [Install graphify skill & tool]  [Skip — higher token usage]
- User skips → `USE_GRAPHIFY=false`. User installs → run graphify, then proceed.

---

### Phase 1: Discovery

#### 1.1: Build Deterministic File Manifest

Use the **`Glob` tool** (NOT LLM file-selection) to build a manifest of all
relevant files. For each category, run the glob patterns listed in
`templates/file-manifest.json` (`glob_patterns_used`).

Write the manifest to `.claude/scratchpad/spring-boot-review/file-manifest.json`
using the template in `templates/file-manifest.json`. Each file entry includes:
- `path`: relative path from target root
- `size_bytes`: file size
- `categories`: list of categories this file is relevant to
- `shard`: initially 0, updated if sharding is applied

**If graphify available:** query the knowledge graph (see
`references/graphify-queries.md` discovery section) to supplement file metadata
but still build the manifest with `Glob`.

**If graphify NOT available:** the manifest content is used to determine which
files to scan. Optionally, build a file cache by dispatching a dedicated
**cache-builder Task subagent**. The subagent reads every file in the manifest and
writes cached copies to `.claude/scratchpad/spring-boot-review/file-cache/{relative-path}.txt`.
The parent does NOT read source files — the subagent's context is isolated.

#### 1.2: Compute Token Budget & Sharding

1. Sum file sizes by category from the manifest.
2. Compare against Task subagent context window (~100K tokens ≈ 400KB source).
3. If any category's total bytes exceed 75% of the context window:
   - **Shard the manifest**: split files deterministically (alphabetically)
     into N batches, each ≤75% of context window.
   - Set `sharding.required = true` in the manifest.
   - Set `token_budget.sharding_required = true` in `.status.json`.
4. If sharding would require >4 shards per category AND total files >500:
   - **Auto-degrade scope** to next tier down. Warn user:
     "Project exceeds Deep analysis budget — falling back to Basic scope with
     guaranteed full coverage."
   - Update depth/rigor in `.status.json`.

#### 1.3: Determine Triviality (Deterministic)

See `references/depth-tiers.md` for thresholds. The project is **trivial** if
ALL of:
- ≤ 20 Java/Kotlin source files
- ≤ 5 controllers
- ≤ 5 services
- ≤ 3 repositories
- ≤ 3 configuration classes
- NOT multi-module
- ≤ 30 direct dependencies

- **Trivial** → depth = `cursory`, rigor = `cursory`. Log reason to `.status.json`
  (`triviality_reason`). Skip depth prompt and SB4 migration prompt.
- **Non-trivial** → prompt for depth (cursory/basic/deep). If `depth` parameter
  was provided, use it directly (skip prompt). Map chosen depth to matching
  scope + rigor tier.

**Always log the depth and rigor to `.status.json`** with the reason, even for
trivial projects.

#### 1.4: Write Discovery Summary

Write summary stats to `.claude/scratchpad/spring-boot-review/discovery.md` using
`templates/discovery-template.md`. Include:
- Detected `{SB_VERSION}`
- Triviality reason
- Depth and rigor selected
- Token budget estimates
- Sharding status

#### 1.5: Spring Boot 4.x Migration Prompt

Only if non-trivial AND SB version < 4.0.0:

After depth is chosen, prompt the user:

> Detected Spring Boot **{version}** (< 4.0.0).
>
> Include **Spring Boot 4.x migration analysis**? This adds a 9th category
> (`sb4-migration`) that audits:
> - Testing migration (`@MockBean` → `@MockitoBean`, MockMvc configuration)
> - Spring Security 7 changes (CSRF for APIs, lambda DSL requirement)
> - Starter renames and auto-config modularization
> - Jackson 3 package relocation (`com.fasterxml.jackson` → `tools.jackson`)
>
> **[Include migration analysis]** (recommended)
> **[Skip — analyze current version only]**

- User chooses **Include** → add `sb4-migration` to active categories.
- User chooses **Skip** → exclude `sb4-migration`.

#### 1.6: Compute Config Hash

Compute `config_hash = sha256("{depth}|{rigor}|{active_categories}|{skill_version}")`.
Store in `.status.json`. This is used in Phase 0 resume checks to detect
parameter changes between runs.

---

### Phase 2: Parallel Category Analysis

#### 2.0: Initialize Scratchpad

```bash
mkdir -p .claude/scratchpad/spring-boot-review
# Set restrictive permissions
chmod 700 .claude/scratchpad/spring-boot-review 2>/dev/null || true
```

Write `.status.json` from `templates/status.json`, including `target`,
`project_fingerprint`, `manifest_hash`, `config_hash`, `sb_version`,
`sb4_migration_included`, `depth`, `rigor`, `triviality_reason`,
and `token_budget`. Mark active categories as `pending` (or `complete`
if resuming). Mark excluded categories as `skipped`.

Create empty scratchpad files from `templates/scratchpad-section.md`
for each active category (including `sb4-migration.md` if included).
The scratchpad template includes the heartbeat checklist section
and the completion marker area.

**Add to `.gitignore`:**
```bash
echo "" >> .gitignore 2>/dev/null || touch .gitignore
echo "# Spring Boot Review scratchpad — security-sensitive" >> .gitignore
echo ".claude/scratchpad/" >> .gitignore
```

#### 2.1: Build Task Subagent Prompts

For each category, build a prompt from `references/analysis-prompts.md`
(Category Analysis Task template). Fill in all placeholders:

| Placeholder | Source |
|-------------|--------|
| `{CATEGORY}` | Category ID |
| `{SB_VERSION}` | Detected Spring Boot version (from Phase 0) |
| `{DEPTH}` | Chosen depth tier |
| `{RIGOR}` | Chosen rigor tier |
| `{MAX_FINDINGS}` | From `references/depth-tiers.md` (per-category limits by rigor) |
| `{WORD_LIMIT}` | From `references/depth-tiers.md` |
| `{TIMEOUT}` | From `timeout` parameter |
| `{PROJECT_ROOT}` | Resolved absolute target path (no symlinks) |
| `{FILE_LIST}` | Subset of `file-manifest.json` for this category (per-shard if sharding) |
| `{N_FILES}` | Number of files in this category's subset |
| `{rigor_instructions}` | From `references/analysis-prompts.md` Rigor Instructions section |
| `{graphify_mode_instructions}` | From `references/analysis-prompts.md` if USE_GRAPHIFY, else empty |
| `{file_cache_mode_instructions}` | From `references/analysis-prompts.md` if !USE_GRAPHIFY, else empty |
| `{sharding_instructions}` | From `references/analysis-prompts.md` if sharding, else empty |
| `{SHARD_N}` | Shard number (if sharding) |
| `{TOTAL_SHARDS}` | Total shards (if sharding) |
| `{SHARD_FILE_LIST}` | File subset for this shard (if sharding) |

For the `sb4-migration` Task subagent, use the dedicated prompt template from
`references/analysis-prompts.md` (sb4-migration Task Subagent section).

**Per-category Task permissions** (include in Task config):

```
- ALLOW: read files within {PROJECT_ROOT}
- ALLOW: write to .claude/scratchpad/spring-boot-review/{CATEGORY}.md
- ALLOW: read .claude/scratchpad/spring-boot-review/.status.json and update it
- ALLOW: read .claude/scratchpad/spring-boot-review/file-manifest.json
- DENY: executing shell commands (except for read operations)
- DENY: web fetch or web search
- DENY: editing any file outside .claude/scratchpad/spring-boot-review/
```

#### 2.2: Dispatch

Dispatch Claude Code `Task` subagents for all pending categories, up to `max_parallel`
at a time (which may now be up to 9 categories if sb4-migration is included, plus
additional Task subagents per category if sharding is active).
If >4 Task subagents total, run in waves.

Use the `Task` tool with `subagent_type` appropriate for analysis work. Each Task
receives the built prompt with the category analysis instructions.

**Sharding dispatch:** If a category requires N shards, dispatch N Task subagents
for that category, each with its shard-specific file list. All shard subagents
for a category write to the same scratchpad file with append semantics.

#### 2.3: Guard Rules

1. **One category per Task group** — all shards for a category share a scratchpad file.
2. **Separate scratchpad files per category** — no two categories share a file.
3. **Fixed scope** — file lists determined in Phase 1 manifest, never expanded.
4. **No retries** — error → note and move on.
5. **Hard timeout** — exceed timeout → category marked `failed`, heartbeat shows partial progress.
6. **Finding cap** — per `references/depth-tiers.md` (by rigor tier).
7. **Sandbox** — every Task prompt includes the project root boundary.
8. **Secrets redacted** — never write actual secret values to scratchpad.
9. **Heartbeat required** — each Task updates the file progress checklist after every file.
10. **Completion marker required** — Task writes `ANALYSIS COMPLETE` or `ANALYSIS PARTIAL` at end.

#### 2.4: Check Completion

Read `.status.json` — this is a ~30 line JSON file. **Never read scratchpad
category files (`*.md`) from the parent session.** They exist solely for the
dedup, scoring, and report assembly Task subagents in later phases.

For each category scratchpad, check the completion marker at the bottom:
- `ANALYSIS COMPLETE: N/N files` → category is fully analyzed.
- `ANALYSIS PARTIAL: X/N files` → category has partial coverage. Flag for warning.
- No marker → category likely failed/timed out. Treat as partial.

For `failed` categories: note in report. For `pending`
(should not happen): re-dispatch if within retry budget.

---

### Phase 2.5: Deduplication

Spawn a single Claude Code `Task` subagent using the **Deduplication Task** prompt from
`references/analysis-prompts.md`.

**Purpose:** Merge cross-category findings that describe the same underlying
issue. Two category Tasks (e.g., security + configuration) may independently flag
the same problem. The dedup Task merges these by file location so the
penalty is only applied once.

**Output:** `.claude/scratchpad/spring-boot-review/deduped-findings.json` using
the template at `templates/deduped-findings.json`.

**Merge key:** `location` field (file:method). Two findings at the same
file and method with similar descriptions are likely duplicates.

---

### Phase 2.6: Deterministic Scoring

Spawn a single Claude Code `Task` subagent using the **Scoring Task** prompt from
`references/analysis-prompts.md`.

**Purpose:** Review severity assignments against calibration examples and
compute the final score deterministically. This is a two-pass process:

- **Pass 1:** Review each finding's severity against `references/severity-calibration.md`.
- **Pass 2:** Consistency check — verify similar findings received similar severities.

**Score computation (deterministic arithmetic):**

```
Penalty sum = (CRITICAL count × 10) + (HIGH count × 5) + (MEDIUM count × 2)
            + (LOW count × 1) + (INFO count × 0)

Score = max(0, 100 − penalty_sum)
```

**Output:** Updated `deduped-findings.json` with:
- Final severity for each finding
- `severity_counts` by severity level
- `pre_computed_score`, `pre_computed_grade`, `pre_computed_grade_label`, `pre_computed_color`

**Cross-check:** The scoring Task verifies that
`100 − sum(severity_counts × penalties) == pre_computed_score`.

Store `pre_computed_score` and `pre_computed_grade` in `.status.json` for the
report assembly Task.

---

### Phase 3: Report Assembly

Spawn a single Claude Code `Task` subagent using the **Report Assembly Task** prompt from
`references/analysis-prompts.md`.

**Key rule:** The score is **pre-computed** — the report assembly
Task reads it from `deduped-findings.json` and does NOT calculate it.
It performs a cross-check to verify the arithmetic matches.

**Two-pass strategy:**

- **Pass 1:** Read severity + title + location from each deduplicated finding.
  Build Executive Summary, Summary Table, and Overall Score section (using
  pre-computed values).
- **Pass 2:** Read only CRITICAL and HIGH findings in full for the detailed
  section. MEDIUM/LOW/INFO findings → one-line summaries.

**Partial category warnings:** Check each category scratchpad for completion
markers. If any category has `ANALYSIS PARTIAL`, include a visible ⚠️ warning
in the report's "Analysis Completeness" section.

**Scoring formula** (for display only — score is pre-computed):

```
Score = max(0, 100 - total_penalties)

Penalties: CRITICAL: -10 | HIGH: -5 | MEDIUM: -2 | LOW: -1 | INFO: 0

Grades: A 90-100 (green) | B 75-89 (blue) | C 60-74 (yellow) |
        D 40-59 (orange) | F 0-39 (red)
```

Include `sb4-migration.md` findings in the report alongside other categories.
Label them clearly as "Spring Boot 4.x Migration Readiness" findings.

Cross-category findings appear under their `primary_category` with a
"Cross-referenced in: {other categories}" note.

Use `templates/report.md` for structure. Write output to `{output_dir}/spring-boot-review-report.md`.

**Report Task response:** The Task must return exactly one line:
`Report written to {output_dir}/spring-boot-review-report.md — {N} findings, Score: {SCORE}/100 ({GRADE})`.
The parent only needs to confirm success for Phase 4 (PDF) and Phase 5 (cleanup).
The report content lives on disk — never echo it into parent context.

---

### Phase 4: PDF Generation

- **Windows:** `claude-code/scripts/generate-pdf.bat <report_path>`
- **macOS/Linux:** `claude-code/scripts/generate-pdf.sh <report_path>`

Tries: `npx md-to-pdf` → `pandoc` → markdown-only delivery on failure.

---

### Phase 5: Cleanup

- `yes`: delete `.claude/scratchpad/spring-boot-review/`.
- `no`: leave in place.
- `ask`: prompt user.

---

## Finding Format

Every finding MUST follow this structure and include a `location` field
for deduplication:

```markdown
### [SEVERITY] Short Title

- **File:** `path/to/File.java:42-58`
- **Location:** `path/to/File.java:methodName` (merge key for dedup)
- **Finding:** Clear description (≤50 words). **Never include actual secret values — use `[REDACTED]`.**
- **Impact:** Why it matters (≤30 words)
- **Suggestion:** Concrete fix (≤50 words)
- **References:** (optional, ≤30 words)

---
```

## Error Recovery

- Task timeout → mark `failed` or `partial`. Heartbeat shows progress.
  Report notes skipped/partial categories.
- Corrupted `.status.json` → treat all as `pending`, re-dispatch.
- Dedup failure → proceed with raw findings (no dedup), note in report.
- Scoring failure → report assembly computes score as fallback, note in report.
- Report assembly failure → raw findings preserved in scratchpad.
- PDF failure → deliver markdown report, note failure.

## Reference Files

Load these as needed (not loaded into context automatically):

| File | When to Load |
|------|-------------|
| `references/depth-tiers.md` | Phase 1 (triviality check, depth prompt, token budget/sharding) |
| `references/severity-calibration.md` | Phase 2.6 (scoring Task) |
| `references/graphify-queries.md` | Phase 2 (graphify mode Task instructions) |
| `references/analysis-prompts.md` | Phase 2 (category Tasks), Phase 2.5 (dedup), Phase 2.6 (scoring), Phase 3 (report assembly) |
| `references/category-guides.md` | Loaded by each category Task for pattern detection |
| `references/sb4-migration-checks.md` | Loaded by sb4-migration Task |
| `references/sb4-starter-migration.md` | Loaded by sb4-migration Task for dependency audit |
| `templates/status.json` | Phase 0 (resume check), Phase 2 (initialize scratchpad) |
| `templates/file-manifest.json` | Phase 1 (manifest structure + glob patterns) |
| `templates/discovery-template.md` | Phase 1 (write discovery summary) |
| `templates/scratchpad-section.md` | Phase 2 (initialize per-category scratchpad files) |
| `templates/deduped-findings.json` | Phase 2.5 (dedup output structure) |
| `templates/report.md` | Phase 3 (report structure) |

## Phase Summary

| Phase | Name | New in v2.0? | Purpose |
|-------|------|-------------|---------|
| 0 | Setup & Resume | Updated | Enhanced fingerprint (content + manifest + config + version hashes) |
| 0.5 | Graphify Check | — | Detect/install graphify for token reduction |
| 1 | Discovery | Updated | Deterministic `Glob`-based file manifest, token budget + sharding, deterministic triviality |
| 2 | Parallel Analysis | Updated | Heartbeat tracking, completion markers, sharded dispatch |
| 2.5 | Deduplication | **NEW** | Merge cross-category duplicates by file location |
| 2.6 | Deterministic Scoring | **NEW** | Severity calibration + arithmetic score outside LLM |
| 3 | Report Assembly | Updated | Pre-computed score with cross-check, partial category warnings |
| 4 | PDF Generation | — | md-to-pdf or pandoc fallback |
| 5 | Cleanup | — | Prompt to keep/delete scratchpad |