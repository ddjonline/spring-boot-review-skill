# Spring Boot Review — OpenCode Skill (v2.0)

A multi-phase OpenCode skill that analyzes Java Spring Boot applications and produces a curated audit report with scored findings across 8 categories: security, performance, code quality, configuration, dependencies, error handling, testing, and API design. Optionally includes a Spring Boot 4.x migration readiness audit for pre-4.x projects.

## What's New in v2.0: Deterministic Re-run Consistency

Running this skill twice on the same unchanged codebase with the same user choices now produces:

- **Same score and grade** — Score is computed arithmetically outside the LLM, then cross-checked.
- **Same finding locations and severities** — Deterministic file manifest, scope+rigor checklists, severity calibration examples.
- **Same deduplicated findings** — Cross-category duplicates merged by file location before scoring.
- **Visible partial coverage** — Heartbeat tracking and completion markers show exactly which files were analyzed.

The report narrative (executive summary, key takeaways) will differ in wording since it's LLM-generated, but the underlying data is consistent.

## Summary

`spring-boot-review` performs deep static analysis of a Spring Boot codebase by dispatching parallel subagents — one per analysis category. Each subagent writes findings to a dedicated scratchpad file on disk, keeping the parent session's context window lean (~5K tokens overhead). Once all categories complete, deduplication and scoring phases run before a curation subagent assembles the findings into a scored, color-coded report with an executive summary, critical-finding details, and a letter grade (A–F).

**Key design principles:**
- **Scratchpad offloading** — Findings never accumulate in the parent or subagent context windows. They stream directly to per-category Markdown files.
- **Parallel execution** — Up to 4 category subagents run concurrently. Large projects with all 8 categories complete in ~5–15 minutes.
- **Token efficiency** — When [graphify](https://github.com/safishamsi/graphify) is available, subagents query a pre-built knowledge graph instead of re-reading files, reducing token usage by ~60–84%.
- **Version-aware** — Automatically detects the Spring Boot version and adapts guidance. Pre-4.x projects are offered an optional migration audit.
- **Re-run determinism** — Fixed file manifests, deduplication, pre-computed scoring, and heartbeat tracking ensure consistent results across runs.

## Architecture

```
                    ┌──────────────────────────────┐
                    │        Parent Session          │
                    │  (~5K tokens, no findings)     │
                    │  Orchestrates phases,          │
                    │  dispatches subagents,         │
                    │  reads only .status.json       │
                    └──────────┬───────────────────┬─┘
                               │                   │
              ┌────────────────▼─────┐   ┌─────────▼──────────────┐
              │  Subagent: Security   │   │  Subagent: Performance  │
              │  Fixed file manifest  │   │  Fixed file manifest    │
              │  Heartbeat tracking   │   │  Heartbeat tracking     │
              │  Writes to disk       │   │  Writes to disk         │
              └───────────────────────┘   └────────────────────────┘
                               │                   │
              ┌────────────────▼─────┐   ┌─────────▼──────────────┐
              │  ...6 more categories │   │  sb4-migration (opt.)   │
              └───────────────────────┘   └────────────────────────┘
                               │                   │
                    ┌──────────▼───────────────────▼────────────┐
                    │      .opencode/scratchpad/ (disk)          │
                    │  security.md  performance.md  ...          │
                    │  file-manifest.json  .status.json          │
                    └────────────────────┬──────────────────────┘
                                         │
                    ┌────────────────────▼──────────────────────┐
                    │  Phase 2.5: Deduplication Subagent         │
                    │  Merges cross-category duplicates          │
                    │  Writes deduped-findings.json              │
                    └────────────────────┬──────────────────────┘
                                         │
                    ┌────────────────────▼──────────────────────┐
                    │  Phase 2.6: Deterministic Scoring          │
                    │  Severity calibration + arithmetic score   │
                    │  Updates deduped-findings.json             │
                    └────────────────────┬──────────────────────┘
                                         │
                    ┌────────────────────▼──────────────────────┐
                    │  Phase 3: Report Assembly Subagent         │
                    │  Pre-computed score + cross-check          │
                    │  Two-pass: summary → critical/high detail  │
                    └────────────────────┬──────────────────────┘
                                         │
                    ┌────────────────────▼──────────────────────┐
                    │  Output: spring-boot-review-{project}-     │
                    │  {user}-{timestamp}.md + .pdf              │
                    │  Score: 73/100 (C) — Needs Improvement     │
                    └───────────────────────────────────────────┘
```

### Phase Flow

| Phase | Description | v2.0 Change |
|-------|-------------|-------------|
| **0 — Setup** | Parse parameters, detect Spring Boot version, compute compound fingerprint (content + manifest + config + version hashes), derive project/user names, check for prior scratchpad (resume/fresh) | Enhanced fingerprint + output filename vars |
| **0.5 — Graphify** | Detect graphify installation, prompt to install or skip, build knowledge graph if needed | — |
| **1 — Discovery** | Build deterministic file manifest via `glob`, compute token budget + sharding, determine triviality against documented thresholds, prompt for analysis depth, offer SB4 migration audit | Deterministic manifest, token budget, deterministic triviality |
| **2 — Analysis** | Dispatch parallel subagents (one per category, sharded if needed). Heartbeat tracking and completion markers on every scratchpad file | Heartbeat + completion markers, sharding |
| **2.5 — Dedup** | Single subagent merges cross-category duplicates by file location. Writes `deduped-findings.json` | **NEW** |
| **2.6 — Scoring** | Single subagent reviews severity against calibration examples, computes score arithmetically. Updates `deduped-findings.json` | **NEW** |
| **3 — Report** | Single subagent assembles curated report using pre-computed score with cross-check, partial-category warnings, dynamic filename | Pre-computed score, cross-check, structured filename |
| **4 — PDF** | Generate PDF via `npx md-to-pdf` (primary) or `pandoc` (fallback) | — |
| **5 — Cleanup** | Prompt to keep or delete scratchpad files | — |

## Installation

### Using the Installer (recommended)

From the repository root, run the installer to install the OpenCode skill:

```bash
# Install both platforms globally:
./install.sh

# Install only the OpenCode skill globally:
./install.sh --opencode-only

# Install locally into a project:
./install.sh --local --target /path/to/your-project --opencode-only
```

The installer copies the skill directory to the correct OpenCode location.

### Manual Installation

**Into an existing project:**
```bash
cp -r opencode-skill/.opencode/skills/spring-boot-review /path/to/your-project/.opencode/skills/spring-boot-review
```

**Global:**
```bash
cp -r opencode-skill/.opencode/skills/spring-boot-review ~/.config/opencode/skills/spring-boot-review
```

### Recommended opencode.jsonc settings

```jsonc
{
  "$schema": "https://opencode.ai/config.json",
  "experimental": {
    "subagent_depth": 2
  }
}
```

`subagent_depth: 2` allows subagents to spawn their own subagents — required for the file-cache builder and graphify integration.

## Usage

Invoke in an OpenCode session:

```
@spring-boot-review
```

With parameters:

```
@spring-boot-review target=./my-spring-app categories=security,performance,dependencies depth=deep cleanup=no
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `target` | auto-discover | Directory or path to analyze |
| `categories` | `all` (8) | Comma-separated subset: `security`, `performance`, `code-quality`, `configuration`, `dependencies`, `error-handling`, `testing`, `api-design` |
| `output_dir` | project root | Where to write the report |
| `cleanup` | `ask` | `yes`, `no`, or `ask` — delete scratchpad after report? |
| `timeout` | `300` | Per-subagent timeout in seconds |
| `max_parallel` | `4` | Max concurrent category subagents |
| `depth` | auto | `cursory`, `basic`, or `deep`. Overrides triviality auto-detection. |

### Interactive Prompts

During execution, the skill will prompt you for:

1. **Graphify installation** (if not detected) — install to reduce token usage, or skip.
2. **Analysis depth** (if non-trivial project) — Cursory / Basic / Deep.
3. **SB4 migration audit** (if version < 4.0.0) — include a 9th migration category, or skip.
4. **Resume or fresh** (if prior scratchpad exists and fingerprint matches) — continue from where you left off.
5. **Cleanup** (if `cleanup=ask`) — keep or delete scratchpad files.

**Note:** To achieve re-run consistency, make the same interactive choices across runs. The `depth` parameter bypasses the depth prompt. All choices are logged to `.status.json` for auditability.

### Depth Tiers

| Tier | Scope | Rigor | Findings/Category | Est. Time | Est. Tokens |
|------|-------|-------|-------------------|-----------|-------------|
| **Cursory** | Key files (top 20% of manifest) | Grep/pattern match, top-3 per file | 1–3 | ~2–3 min | ~20K |
| **Basic** | All main sources from manifest | Full-file read with structured checklist | 3–8 | ~5–10 min | ~50K |
| **Deep** | Sources + tests + resources from manifest | Basic + call-chain tracing + cross-referencing | 10–20 | ~15–30 min | ~100K+ |

Token estimates assume graphify is being used. Without graphify, multiply by 2–4×.

### Output

```
{project_root}/
├── spring-boot-review-{project}-{user}-{timestamp}.md    # Curated Markdown report
├── spring-boot-review-{project}-{user}-{timestamp}.pdf   # PDF version (if converter available)
└── .opencode/scratchpad/
    └── spring-boot-review/
        ├── .status.json
        ├── discovery.md
        ├── file-manifest.json
        ├── deduped-findings.json
        ├── security.md
        ├── performance.md
        ├── ...
        └── sb4-migration.md    (if included)
```

### Report Structure

1. **Overall Score** — Color-coded score badge (73/100 — C 🟡). Score cross-check table showing pre-computed vs. counts-derived match.
2. **Analysis Completeness** — ⚠️ Warnings for any partially-analyzed categories (files-processed/total-files).
3. **Executive Summary** — Total findings, raw vs. deduplicated counts, findings-by-category table with completion status, key takeaways.
4. **Critical & High Findings** — Full details with file locations, impacts, and concrete fix suggestions.
5. **Categorized Findings** — All findings organized by category, ordered by severity. Cross-category findings noted.
6. **Appendix** — Scan metadata, methodology (v2.0 pipeline), severity definitions, token cost estimate.

### Scoring Model

| Severity | Penalty | When Used |
|----------|---------|-----------|
| CRITICAL | –10 | Security vulnerability, data loss risk, production outage risk |
| HIGH | –5 | Significant bug, performance degradation, missing critical tests |
| MEDIUM | –2 | Code smell, minor perf issue, inconsistent pattern |
| LOW | –1 | Style issue, missing documentation, improvement suggestion |
| INFO | 0 | Observation, no action needed |

| Score | Grade | Color | Label |
|-------|-------|-------|-------|
| 90–100 | **A** | 🟢 Green | Excellent |
| 75–89 | **B** | 🔵 Blue | Good |
| 60–74 | **C** | 🟡 Yellow | Needs Improvement |
| 40–59 | **D** | 🟠 Orange | At Risk |
| 0–39 | **F** | 🔴 Red | Critical Issues |

**Score formula:** `max(0, 100 − (C×10 + H×5 + M×2 + L×1))` — computed deterministically in Phase 2.6, not by the LLM.

## Prerequisites

| Dependency | Required? | Purpose |
|-----------|-----------|---------|
| OpenCode V2 | ✓ | Runtime |
| graphify | Recommended | Pre-indexes codebase, reduces token usage 60–84% |
| Node.js + npx | Optional | PDF generation via `md-to-pdf` |
| pandoc | Optional | PDF generation fallback |

Without Node.js or pandoc, the report is delivered as Markdown only.

## Caveats & Limitations

### Re-run Consistency
v2.0 guarantees consistent scores, severities, and finding locations across re-runs on the same unchanged codebase when the same interactive choices are made. Narrative text (executive summary, key takeaways) will differ in wording since it is LLM-generated. Graphify knowledge graph construction may introduce minor variability (upstream dependency).

### Security of Findings
The scratchpad directory (`.opencode/scratchpad/spring-boot-review/`) contains a detailed security audit of your application, including the locations of vulnerabilities. The skill automatically appends `.opencode/scratchpad/` to `.gitignore` and sets restrictive permissions (`chmod 700`). **Do not manually commit scratchpad files to version control.**

### Secrets in Findings
The skill instructs subagents to redact actual secret values in findings (replaced with `[REDACTED]`). However, the scratchpad files should still be treated as sensitive.

### Spring Boot Version Detection
Version detection relies on standard `pom.xml` (`<parent>` or `<properties>`) or `build.gradle` (`springBootVersion` or plugin version) structure. Non-standard build configurations may not detect correctly.

### Large Projects
- **500+ files**: Deep analysis with sharding enabled. Auto-degrade to lower scope tier if sharding would require >4 shards per category.
- **Multi-module Maven/Gradle projects**: Analysis scope includes all modules by default. Use `target` to narrow to a specific module.

### Partial Coverage
If a subagent times out or hits context limits, its scratchpad file includes a `PARTIAL` marker and heartbeat showing exactly how many files were processed. The report includes a visible ⚠️ warning.

### PDF Generation
- `npx md-to-pdf` downloads packages on first use (requires internet).
- Falls back to `pandoc` with `wkhtmltopdf` or `weasyprint` engine.
- If both fail, the Markdown report is delivered without PDF.