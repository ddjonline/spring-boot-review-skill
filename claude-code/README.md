# Spring Boot Review — Claude Code Custom Slash Command (v2.0)

A multi-phase Claude Code custom slash command that analyzes Java Spring Boot applications and produces a curated audit report with scored findings across 8 categories: security, performance, code quality, configuration, dependencies, error handling, testing, and API design. Optionally includes a Spring Boot 4.x migration readiness audit for pre-4.x projects.

## What's New in v2.0: Deterministic Re-run Consistency

Running this command twice on the same unchanged codebase with the same user choices now produces:

- **Same score and grade** — Score is computed arithmetically outside the LLM, then cross-checked.
- **Same finding locations and severities** — Deterministic file manifest, scope+rigor checklists, severity calibration examples.
- **Same deduplicated findings** — Cross-category duplicates merged by file location before scoring.
- **Visible partial coverage** — Heartbeat tracking and completion markers show exactly which files were analyzed.

The report narrative (executive summary, key takeaways) will differ in wording since it's LLM-generated, but the underlying data is consistent.

## Summary

`/spring-boot-review` performs deep static analysis of a Spring Boot codebase by dispatching parallel Claude Code Task subagents — one per analysis category. Each subagent writes findings to a dedicated scratchpad file on disk, keeping the parent session's context window lean. Once all categories complete, deduplication and scoring phases run before a curation subagent assembles the findings into a scored, color-coded report with an executive summary, critical-finding details, and a letter grade (A–F).

**Key design principles:**
- **Scratchpad offloading** — Findings never accumulate in the parent or subagent context windows. They stream directly to per-category Markdown files.
- **Parallel execution** — Up to 4 category Task subagents run concurrently. Large projects with all 8 categories complete in ~5–15 minutes.
- **Token efficiency** — When [graphify](https://github.com/safishamsi/graphify) is available, subagents query a pre-built knowledge graph instead of re-reading files, reducing token usage by ~60–84%.
- **Version-aware** — Automatically detects the Spring Boot version and adapts guidance. Pre-4.x projects are offered an optional migration audit.
- **Re-run determinism** — Fixed file manifests, deduplication, pre-computed scoring, and heartbeat tracking ensure consistent results across runs.

## Architecture

```
                    ┌──────────────────────────────┐
                    │        Parent Session          │
                    │  (~5K tokens, no findings)     │
                    │  Orchestrates phases,          │
                    │  dispatches Task subagents,    │
                    │  reads only .status.json       │
                    └──────────┬───────────────────┬─┘
                               │                   │
              ┌────────────────▼─────┐   ┌─────────▼──────────────┐
              │  Task: Security       │   │  Task: Performance      │
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
                    │      .claude/scratchpad/ (disk)            │
                    │  security.md  performance.md  ...          │
                    │  file-manifest.json  .status.json          │
                    └────────────────────┬──────────────────────┘
                                         │
                    ┌────────────────────▼──────────────────────┐
                    │  Phase 2.5: Deduplication Task             │
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
                    │  Phase 3: Report Assembly Task             │
                    │  Pre-computed score + cross-check          │
                    │  Two-pass: summary → critical/high detail  │
                    └────────────────────┬──────────────────────┘
                                         │
                    ┌────────────────────▼──────────────────────┐
                    │  Output: spring-boot-review-report.md + .pdf    │
                    │  Score: 73/100 (C) — Needs Improvement     │
                    └───────────────────────────────────────────┘
```

### Phase Flow

| Phase | Description |
|-------|-------------|
| **0 — Setup** | Parse parameters, detect Spring Boot version, compute compound fingerprint, check for prior scratchpad (resume/fresh) |
| **0.5 — Graphify** | Detect graphify installation, prompt to install or skip, build knowledge graph if needed |
| **1 — Discovery** | Build deterministic file manifest via glob, compute token budget + sharding, determine triviality, prompt for analysis depth, offer SB4 migration audit |
| **2 — Analysis** | Dispatch parallel Task subagents (one per category, sharded if needed). Heartbeat tracking and completion markers on every scratchpad file |
| **2.5 — Dedup** | Single Task subagent merges cross-category duplicates by file location |
| **2.6 — Scoring** | Single Task subagent reviews severity against calibration examples, computes score arithmetically |
| **3 — Report** | Single Task subagent assembles curated report using pre-computed score with cross-check |
| **4 — PDF** | Generate PDF via `npx md-to-pdf` (primary) or `pandoc` (fallback) |
| **5 — Cleanup** | Prompt to keep or delete scratchpad files |

### Context Isolation

| What lives where | Parent | Task Subagent | Disk |
|------------------|--------|---------------|------|
| Command instructions | ✓ (once) | — | — |
| Source file contents | — | ✓ | ✓ (cache) |
| Finding details | — | — | ✓ (scratchpad) |
| Deduplicated findings | — | — | ✓ (deduped-findings.json) |
| Pre-computed score | ✓ (tiny) | ✓ (scoring) | ✓ (deduped-findings.json) |
| Report content | — | ✓ (during assembly) | ✓ (output) |
| `.status.json` | ✓ (tiny) | ✓ (update) | ✓ |
| Task completion signals | ✓ (1 line each) | — | — |

## Installation

### Into an existing project

Copy the `claude-code/` directory into your project:

```bash
cp -r spring-boot-review-skill/claude-code/.claude /path/to/your-project/.claude
cp -r spring-boot-review-skill/claude-code/references /path/to/your-project/.claude/references/spring-boot-review/
cp -r spring-boot-review-skill/claude-code/templates /path/to/your-project/.claude/templates/spring-boot-review/
cp -r spring-boot-review-skill/claude-code/scripts /path/to/your-project/.claude/scripts/spring-boot-review/
```

Or use the one-liner:

```bash
cp -r spring-boot-review-skill/claude-code/{.claude,references,templates,scripts} /path/to/your-project/
```

Claude Code auto-discovers custom slash commands under `.claude/commands/`. No additional configuration is required.

### As a global command

```bash
cp spring-boot-review-skill/claude-code/.claude/commands/spring-boot-review.md ~/.claude/commands/spring-boot-review.md
```

Note: Reference files, templates, and scripts would need to be at a known global path or embedded in the command file for global use.

## Usage

Invoke the command in a Claude Code session:

```
/spring-boot-review
```

Or with parameters:

```
/spring-boot-review target=./my-spring-app categories=security,performance,dependencies depth=deep cleanup=no
```

### Parameters

| Parameter | Default | Description |
|-----------|---------|-------------|
| `target` | auto-discover | Directory or path to analyze |
| `categories` | `all` (8) | Comma-separated subset: `security`, `performance`, `code-quality`, `configuration`, `dependencies`, `error-handling`, `testing`, `api-design` |
| `output_dir` | project root | Where to write the report |
| `cleanup` | `ask` | `yes`, `no`, or `ask` — delete scratchpad after report? |
| `timeout` | `300` | Per-Task timeout in seconds |
| `max_parallel` | `4` | Max concurrent category Tasks |
| `depth` | auto | `cursory`, `basic`, or `deep`. Overrides triviality auto-detection. |

### Interactive Prompts

During execution, the command will prompt you for:

1. **Graphify installation** (if not detected) — install to reduce token usage, or skip.
2. **Analysis depth** (if non-trivial project) — Cursory / Basic / Deep.
3. **SB4 migration audit** (if version < 4.0.0) — include a 9th migration category, or skip.
4. **Resume or fresh** (if prior scratchpad exists and fingerprint matches) — continue from where you left off.
5. **Cleanup** (if `cleanup=ask`) — keep or delete scratchpad files.

**Note:** To achieve re-run consistency, make the same interactive choices across runs.

### Depth Tiers

| Tier | Scope | Rigor | Findings/Category | Est. Time | Est. Tokens |
|------|-------|-------|-------------------|-----------|-------------|
| **Cursory** | Key files (top 20% of manifest) | Grep/pattern match, top-3 per file | 1–3 | ~2–3 min | ~20K |
| **Basic** | All main sources from manifest | Full-file read with structured checklist | 3–8 | ~5–10 min | ~50K |
| **Deep** | Sources + tests + resources from manifest | Basic + call-chain tracing + cross-referencing | 10–20 | ~15–30 min | ~100K+ |

### Output

```
{project_root}/
├── spring-boot-review-report.md    # Curated Markdown report
├── spring-boot-review-report.pdf   # PDF version (if converter available)
└── .claude/scratchpad/
    └── spring-boot-review/          # Raw findings (cleaned up based on `cleanup` param)
        ├── .status.json
        ├── discovery.md
        ├── file-manifest.json
        ├── deduped-findings.json
        ├── security.md
        ├── performance.md
        ├── ...
        └── sb4-migration.md    (if included)
```

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

## Prerequisites

| Dependency | Required? | Purpose |
|-----------|-----------|---------|
| Claude Code | ✓ | Command runtime |
| graphify | Recommended | Pre-indexes codebase, reduces token usage 60–84% |
| Node.js + npx | Optional | PDF generation via `md-to-pdf` |
| pandoc | Optional | PDF generation fallback |

## Caveats & Limitations

### Re-run Consistency
v2.0 guarantees consistent scores, severities, and finding locations across re-runs on the same unchanged codebase when the same interactive choices are made. Narrative text will differ in wording since it is LLM-generated.

### Security of Findings
The scratchpad directory (`.claude/scratchpad/spring-boot-review/`) contains a detailed security audit of your application, including the locations of vulnerabilities. The command automatically appends `.claude/scratchpad/` to `.gitignore` and sets restrictive permissions (`chmod 700`). **Do not manually commit scratchpad files to version control.**

### Large Projects
- **500+ files**: Deep analysis with sharding enabled. Auto-degrade to lower scope tier if sharding would require >4 shards per category.
- **Multi-module Maven/Gradle projects**: Analysis scope includes all modules by default. Use `target` to narrow to a specific module.

### Partial Coverage
If a Task subagent times out or hits context limits, its scratchpad file includes a `PARTIAL` marker and heartbeat showing exactly how many files were processed. The report includes a visible ⚠️ warning.

### PDF Generation
- `npx md-to-pdf` downloads packages on first use (requires internet).
- Falls back to `pandoc` with `wkhtmltopdf` or `weasyprint` engine.
- If both fail, the Markdown report is delivered without PDF.