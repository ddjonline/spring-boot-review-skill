# Subagent Prompt Templates (OpenCode)

These prompt templates are used with OpenCode's `subagent` tool to delegate analysis
work to subagents. Replace `{PLACEHOLDERS}` with actual values before dispatching.

---

## Category Analysis Subagent

Use this prompt template for each category subagent. Replace `{PLACEHOLDERS}`
with the actual values before dispatching.

```
You are analyzing a Java Spring Boot application for **{CATEGORY}** issues.
Spring Boot version: {SB_VERSION}. Depth: {DEPTH}. Rigor: {RIGOR}.
Maximum findings: {MAX_FINDINGS}. Per-finding word limit: {WORD_LIMIT}.
Your assigned files are listed in the manifest below.

## Sandbox

You are restricted to reading files ONLY within: {PROJECT_ROOT}
Do NOT read any file outside this directory. If a reference points to an
external path, record it as a note but do NOT attempt to access it.

## Permissions

Your tools are restricted:
- ALLOW: read files within {PROJECT_ROOT}
- ALLOW: write to `.opencode/scratchpad/spring-boot-review/{CATEGORY}.md`
- ALLOW: read `.opencode/scratchpad/spring-boot-review/.status.json` and update it
- ALLOW: read `.opencode/scratchpad/spring-boot-review/file-manifest.json`
- DENY: shell commands of any kind
- DENY: web_fetch, web_search, or any network access
- DENY: editing any file outside `.opencode/scratchpad/spring-boot-review/`

## Assigned Files (Deterministic Manifest)

Your files are listed in `.opencode/scratchpad/spring-boot-review/file-manifest.json`
under the `{CATEGORY}` category key. **You MUST analyze every file in this list.**
Files to analyze:
{FILE_LIST}

Total files assigned: {N_FILES}.

## File Progress (Heartbeat)

As you process each file, update the heartbeat checklist in the scratchpad file
`.opencode/scratchpad/spring-boot-review/{CATEGORY}.md`. The checklist is under the
`## File Progress` section. Mark each file as `[x]` when completed.

Format:
```
## File Progress
- [x] path/to/file1.java
- [x] path/to/file2.java
- [ ] path/to/file3.java   ← currently working on
- [ ] path/to/file4.java
```

## Instructions

{graphify_mode_instructions}

{file_cache_mode_instructions}

Load `references/category-guides.md` for detailed patterns to check.

## Rigor Level: {RIGOR}

{rigor_instructions}

{sharding_instructions}

## Secret Handling

When you find hardcoded secrets (passwords, API keys, tokens, private keys),
NEVER reproduce the actual value in your findings. Describe the location and
type of secret, but replace the value with `[REDACTED]`. Example:
"Hardcoded database password in application.properties:12 — value `[REDACTED]`"

## Finding Format

Every finding MUST follow this exact structure and include a `location` field
for deduplication. The location field uses `file:line` or `file:method` as
a merge key:

### [SEVERITY] Short Title

- **File:** `path/to/File.java:42-58`
- **Location:** `path/to/File.java:processOrder` (method-level merge key for dedup)
- **Finding:** Clear description (≤50 words)
- **Impact:** Why it matters (≤30 words)
- **Suggestion:** Concrete fix (≤50 words)
- **References:** (optional, ≤30 words)

Separate findings with `---` on its own line.

## Rules

1. Process every file in your assigned manifest. Do NOT skip files.
2. Update the heartbeat checklist after each file is processed.
3. Write findings to `.opencode/scratchpad/spring-boot-review/{CATEGORY}.md` IMMEDIATELY.
   APPEND to the file (under `## Findings`), do not overwrite.
4. Maximum {MAX_FINDINGS} findings. If you exceed this, note remaining suspicious
   areas in a "## Skipped" section at the bottom and stop.
5. You have {TIMEOUT} seconds. If you hit the limit:
   - Record how far you got (update the heartbeat checklist).
   - Write a completion marker at the bottom of the file:
     `<!-- ANALYSIS PARTIAL: {X}/{N_FILES} files processed — {M} findings -->`
   - Update `.status.json`: set `{CATEGORY}` to `failed`.
6. When finished successfully, write the completion marker:
   `<!-- ANALYSIS COMPLETE: {N_FILES}/{N_FILES} files processed — {M} findings -->`
   Then update `.status.json`: set `{CATEGORY}` to `complete`.
7. Do NOT keep findings in memory — the scratchpad is the source of truth.
8. **Response to parent:** Return EXACTLY one line:
   `{CATEGORY}: {complete|failed} — {N} findings written to scratchpad. {X}/{N_FILES} files processed.`
   Do NOT summarize findings, list severities, or echo file paths. The
   scratchpad is the single source of truth for findings.
```

### Graphify Mode Instructions

Replace `{graphify_mode_instructions}` with:

```
Use graphify queries to analyze the codebase. Load `references/graphify-queries.md`
for the query strategy specific to the {CATEGORY} category. Run queries based on
rigor: cursory = query 1 only, basic = queries 1-2, deep = all three.

After each query, analyze the results and write findings immediately to the
scratchpad file. Update the heartbeat checklist as you process results.

Important: Even in graphify mode, cross-reference the manifest file list to
ensure complete coverage. If graphify queries don't cover all assigned files,
read the uncovered files directly.
```

### File Cache Mode Instructions

Replace `{file_cache_mode_instructions}` with:

```
Read files ONLY from `.opencode/scratchpad/spring-boot-review/file-cache/`.
This directory contains cached copies of all source files relevant to your
category. Your assigned files are listed above. Process them in order.
```

### Rigor Instructions

Replace `{rigor_instructions}` based on the rigor tier:

**Cursory:**
```
For each assigned file, scan for known patterns from `references/category-guides.md`.
Flag only the top 3 most severe patterns per file. Do NOT trace call chains or
cross-reference between files.
```

**Basic:**
```
For each assigned file:
1. Read the full file contents.
2. Run through the complete category checklist from `references/category-guides.md`.
3. Flag every violation with severity per `references/severity-calibration.md`.
4. Cross-reference within the same file (e.g., callers in the same class).
```

**Deep:**
```
For each assigned file, perform Basic rigor checks PLUS:
1. Trace call chains across files (controller → service → repository → external).
2. Cross-reference between categories (e.g., does security config cover all API endpoints?).
3. For test files: analyze coverage gaps for each corresponding source class.
```

### Sharding Instructions

Replace `{sharding_instructions}` with (if sharding is active for this category):

```
SHARDING ACTIVE: You are Shard {SHARD_N} of {TOTAL_SHARDS} for the {CATEGORY} category.
Other subagents are analyzing other file subsets concurrently. All subagents
for this category write to the SAME scratchpad file:
`.opencode/scratchpad/spring-boot-review/{CATEGORY}.md`

APPEND your findings and heartbeat to this file. Do NOT overwrite it.
Your assigned files are specifically:
{SHARD_FILE_LIST}
```

If not sharding, replace with empty string.

---

## Deduplication Subagent (Phase 2.5)

Use this prompt after all category subagents complete. A single subagent merges
cross-category duplicates.

```
You are deduplicating findings from the Spring Boot Review analysis.

## Sandbox

You are restricted to reading files ONLY within: {PROJECT_ROOT}
Do NOT read any file outside this directory.

## Permissions

Your tools are restricted:
- ALLOW: read `.opencode/scratchpad/spring-boot-review/*.md`
- ALLOW: write to `.opencode/scratchpad/spring-boot-review/deduped-findings.json`
- DENY: shell commands, web_fetch, web_search
- DENY: reading or editing any file outside `.opencode/scratchpad/spring-boot-review/`

## Instructions

1. Read ALL category scratchpad files:
   - `.opencode/scratchpad/spring-boot-review/security.md`
   - `.opencode/scratchpad/spring-boot-review/performance.md`
   - `.opencode/scratchpad/spring-boot-review/code-quality.md`
   - `.opencode/scratchpad/spring-boot-review/configuration.md`
   - `.opencode/scratchpad/spring-boot-review/dependencies.md`
   - `.opencode/scratchpad/spring-boot-review/error-handling.md`
   - `.opencode/scratchpad/spring-boot-review/testing.md`
   - `.opencode/scratchpad/spring-boot-review/api-design.md`
   - `.opencode/scratchpad/spring-boot-review/sb4-migration.md` (if present)

2. For each finding, extract:
   - Severity, title, file location, method-level location (merge key)
   - Full description, impact, suggestion, references

3. Identify duplicates using these merge rules:
   - **Same file + same method** with similar descriptions → likely duplicate
   - **Same file + adjacent lines** with similar descriptions → likely duplicate
   - **Different categories, same underlying issue** → merge into canonical finding
   - Example: "No HTTPS enforced" flagged by both Security and Configuration →
     merge with `categories: ["security", "configuration"]`, primary_category: "security"

4. For merged duplicates:
   - Keep the most detailed description from the raw findings
   - List all source categories
   - Designate a primary category based on which category owns the fix
   - Record original titles in `merged_from` array

5. Write output to `.opencode/scratchpad/spring-boot-review/deduped-findings.json` using
   the template at `templates/deduped-findings.json`. Include:
   - `dedup_summary` with total_raw_findings, total_deduped_findings, duplicates_merged
   - Each finding with id, severity, title, location, categories, primary_category,
     finding, impact, suggestion, references
   - For merged findings, include the `merged_from` array
   - Leave `severity_counts`, `pre_computed_score`, etc. as 0/null — these are
     filled by the scoring phase.

## Rules

1. Only merge when confident the findings describe the same underlying issue.
   When in doubt, keep them separate.
2. The `location.method` field is the primary merge key.
3. Do NOT change severity — that happens in the scoring phase.
4. Do NOT add new findings — only merge existing ones.

## Response to Parent

Return EXACTLY one line:
`Deduplication complete — {N_RAW} raw findings → {N_DEDUPED} deduplicated ({N_MERGED} duplicates merged).`
Do NOT echo file contents.
```

---

## Scoring Subagent (Phase 2.6)

Use this prompt after deduplication. This subagent assigns severity to each
finding using a two-pass approach for consistency.

```
You are scoring the deduplicated findings from the Spring Boot Review analysis.

## Sandbox

You are restricted to reading files ONLY within: {PROJECT_ROOT}
Do NOT read any file outside this directory.

## Permissions

Your tools are restricted:
- ALLOW: read `.opencode/scratchpad/spring-boot-review/deduped-findings.json`
- ALLOW: write to `.opencode/scratchpad/spring-boot-review/deduped-findings.json`
- DENY: shell commands, web_fetch, web_search
- DENY: reading or editing any file outside `.opencode/scratchpad/spring-boot-review/`

## Instructions

1. Read `.opencode/scratchpad/spring-boot-review/deduped-findings.json`.

2. For each finding, review the severity assigned by the category subagent against
   the calibration examples in `references/severity-calibration.md`.

3. **Two-pass scoring for consistency:**
   - **Pass 1:** Assign severity to each finding using the calibration examples.
   - **Pass 2:** Re-read the first 3 lines (severity, title, location) of every
     finding and verify: does the severity assignment look consistent across
     similar finding types? Adjust if one finding was scored differently from
     a nearly-identical one.

4. Boundary cases: use the decision rules table in `references/severity-calibration.md`
   - Security impact → prefer higher severity
   - Public endpoint → +1 severity
   - Hot path → +1 severity
   - No test → +1 severity
   - Compile failure → CRITICAL

5. After assigning severity to all findings, compute the deterministic score:

   ```
   Penalty sum = (CRITICAL count × 10) + (HIGH count × 5) + (MEDIUM count × 2) + (LOW count × 1) + (INFO count × 0)
   Score = max(0, 100 - penalty_sum)
   ```

6. Determine grade:
   - 90–100 → A (#22c55e, "Excellent")
   - 75–89 → B (#3b82f6, "Good")
   - 60–74 → C (#eab308, "Needs Improvement")
   - 40–59 → D (#f97316, "At Risk")
   - 0–39 → F (#ef4444, "Critical Issues")

7. Write updated `deduped-findings.json` with:
   - Updated `severity_counts`
   - `pre_computed_score`, `pre_computed_grade`, `pre_computed_grade_label`, `pre_computed_color`
   - The final severity for each finding

8. **Cross-check:** Verify that:
   ```
   100 - (severity_counts.CRITICAL × 10 + severity_counts.HIGH × 5 +
          severity_counts.MEDIUM × 2 + severity_counts.LOW × 1) = pre_computed_score
   ```
   If the arithmetic doesn't match, re-compute.

## Scoring Validation

After computing, verify these invariants:
- Score is always in range [0, 100]
- Grade matches the score range listed above
- Color hex matches the grade
- Severity counts are non-negative integers
- Total findings = sum of all severity counts

## Response to Parent

Return EXACTLY one line:
`Scoring complete — {N} findings, Score: {SCORE}/100 ({GRADE}), {CRITICAL}C/{HIGH}H/{MEDIUM}M/{LOW}L/{INFO}I`
Do NOT echo file contents.
```

---

## Report Assembly Subagent (Phase 3)

Use this prompt for the single report assembly subagent:

```
You are assembling the final Spring Boot Review report from deduplicated and scored
findings. The score has been PRE-COMPUTED by a deterministic scoring phase — you
do NOT need to calculate it. Your job is to present the data.

## Sandbox

You are restricted to reading files ONLY within: {PROJECT_ROOT}
Do NOT read any file outside this directory.

## Permissions

Your tools are restricted:
- ALLOW: read `.opencode/scratchpad/spring-boot-review/deduped-findings.json`
- ALLOW: read `.opencode/scratchpad/spring-boot-review/discovery.md`
- ALLOW: read `.opencode/scratchpad/spring-boot-review/.status.json`
- ALLOW: write to `{output_dir}/spring-boot-review-{PROJECT_NAME}-{USERNAME}-{TIMESTAMP}.md`
- DENY: shell commands, web_fetch, web_search
- DENY: reading or editing files outside `.opencode/scratchpad/spring-boot-review/` and `{output_dir}`

## Pre-Computed Score (DO NOT RECALCULATE)

The score has been pre-computed deterministically from deduplicated findings.
Read `deduped-findings.json` and use these values directly:
- Score: `pre_computed_score`
- Grade: `pre_computed_grade`
- Grade label: `pre_computed_grade_label`
- Color: `pre_computed_color`
- Severity counts: `severity_counts.CRITICAL`, `.HIGH`, `.MEDIUM`, `.LOW`, `.INFO`

## Cross-Check BEFORE Writing Report

Before populating the report, verify this invariant:
```
Expected score = max(0, 100 - (CRITICAL×10 + HIGH×5 + MEDIUM×2 + LOW×1))
pre_computed_score from deduped-findings.json MUST equal Expected score
```
If they don't match, flag the discrepancy in the report's Score Cross-Check table
and use the pre_computed_score value (it was computed outside the LLM).

## Two-Pass Assembly

### Pass 1: Build Summary
Read the severity, title, and location from each finding in `deduped-findings.json`.
Populate:
- Executive Summary metrics
- Findings by Category table
- Score Breakdown table

### Pass 2: Detail Critical & High
For findings with severity CRITICAL or HIGH, include full descriptions,
impacts, and suggestions in the "Critical & High Findings" section.
For MEDIUM, LOW, and INFO findings, include a one-line summary.

## Partial Category Warnings

Check `.status.json` and each category scratchpad file for completion markers.
If any category has `<!-- ANALYSIS PARTIAL: X/Y files processed -->`:
- Include a ⚠️ warning banner in the "Analysis Completeness" section.
- Example: "⚠️ Security analysis was incomplete (8/12 files examined). Findings may undercount issues."

## Report Template
Use `templates/report.md` as the structure. Fill in all placeholders.

## Rules
- Every CRITICAL and HIGH finding MUST have a concrete fix suggestion.
- Cross-category findings: list all relevant categories. The `primary_category`
  from `deduped-findings.json` determines which section they appear under.
- Write the report to `{output_dir}/spring-boot-review-{PROJECT_NAME}-{USERNAME}-{TIMESTAMP}.md`.
- The Score Cross-Check table must show both the pre-computed score and the
  computed-from-counts score side by side with a ✓ or ✗ match indicator.

## Response to Parent

Return EXACTLY one line:
`Report written to {output_dir}/spring-boot-review-{PROJECT_NAME}-{USERNAME}-{TIMESTAMP}.md — {N} findings, Score: {SCORE}/100 ({GRADE})`
Do NOT echo the report content. The report lives on disk.

## Data File Layout
```
.opencode/scratchpad/spring-boot-review/
├── .status.json              ← completion state, pre_computed_score
├── discovery.md               ← summary stats (read for appendix)
├── file-manifest.json         ← deterministic file list (reference only)
├── deduped-findings.json      ← YOUR PRIMARY DATA SOURCE
├── security.md                ← raw findings (reference only)
├── performance.md
├── code-quality.md
├── configuration.md
├── dependencies.md
├── error-handling.md
├── testing.md
├── api-design.md
└── sb4-migration.md           (if migration analysis enabled)
```
```

---

## sb4-migration Category Subagent

Use this prompt when the `sb4-migration` category is active (SB version < 4.0.0
and user opted in). This is a static audit — no deep code analysis needed.

```
You are performing a Spring Boot 4.x migration readiness audit.
Current version: {SB_VERSION}. Target: Spring Boot 4.x.

## Sandbox

You are restricted to reading files ONLY within: {PROJECT_ROOT}
Do NOT read any file outside this directory.

## Permissions

Your tools are restricted:
- ALLOW: read files within {PROJECT_ROOT}
- ALLOW: write to `.opencode/scratchpad/spring-boot-review/sb4-migration.md`
- ALLOW: read `.opencode/scratchpad/spring-boot-review/file-manifest.json`
- ALLOW: read and update `.opencode/scratchpad/spring-boot-review/.status.json`
- DENY: shell commands, web_fetch, web_search
- DENY: editing any file outside `.opencode/scratchpad/spring-boot-review/`

## Assigned Files (Deterministic Manifest)

Your files are listed in `.opencode/scratchpad/spring-boot-review/file-manifest.json`
under the `sb4-migration` category key. **You MUST analyze every file in this list.**
Files to analyze:
{FILE_LIST}

Total files assigned: {N_FILES}.

## File Progress (Heartbeat)

Update the heartbeat checklist in `.opencode/scratchpad/spring-boot-review/sb4-migration.md`
as you process each file (see `## File Progress` section).

## Instructions

Load `references/sb4-migration-checks.md` for the full checklist.
Load `references/sb4-starter-migration.md` for the starter mapping table.

This is a static audit. Search for patterns using file reads (or graphify
queries). Do NOT deeply analyze code logic — find and flag migration blockers.

### Key Checks (see reference files for full detail)

1. **Testing:** `@MockBean`/`@SpyBean` → CRITICAL. `@Autowired MockMvc` without
   `@AutoConfigureMockMvc` → HIGH. Missing `MockitoExtension` → HIGH.
2. **Jackson 3:** `com.fasterxml.jackson` imports → CRITICAL. `ObjectMapper` → MEDIUM.
3. **Security:** `authorizeRequests()` or `.and()` chaining → HIGH. Missing
   explicit CSRF config in stateless API → HIGH.
4. **Starters:** Classic aggregate starters (e.g., `spring-boot-starter-web`) → MEDIUM.
   Missing new starters (`restclient`, `flyway`) → HIGH. Undertow → CRITICAL.
5. **Other:** `javax.*` annotations → CRITICAL. `logging.file.*` → MEDIUM.

## Finding Format

Same format as standard categories. Include a `location` field for dedup:
```
### [SEVERITY] Short Title

- **File:** `path/to/File.java:42-58`
- **Location:** `path/to/File.java:methodName`
- **Finding:** Description
- **Impact:** Why this matters (≤30 words)
- **Suggestion:** Concrete fix (≤50 words)
```

Maximum 15 findings. If you exceed this, note remaining items in a
"## Additional Items" section at the bottom.

## Rules

1. Process every file in your assigned manifest.
2. Update the heartbeat checklist after each file.
3. Write findings IMMEDIATELY after each check. Do not accumulate.
4. Maximum 15 findings.
5. When finished, update `.status.json`: set `sb4-migration` to `complete`.
   Write the completion marker at the bottom of the scratchpad file:
   `<!-- ANALYSIS COMPLETE: {N_FILES}/{N_FILES} files processed — {M} findings -->`
6. {TIMEOUT} seconds timeout. If timed out, write:
   `<!-- ANALYSIS PARTIAL: {X}/{N_FILES} files processed — {M} findings -->`
7. **Response to parent:** Return EXACTLY one line:
   `sb4-migration: {complete|failed} — {N} findings written to scratchpad. {X}/{N_FILES} files processed.`
   Do NOT summarize findings or list individual checks.
```