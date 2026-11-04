# Depth & Rigor Tier Reference

Depth is decomposed into two orthogonal dimensions:

- **Scope** — which files to analyze (determined by file manifest in Discovery)
- **Rigor** — how deeply to analyze each file (concrete analysis checklists below)

---

## Scope: File Coverage (by Tier)

| Tier | Scope | File Source |
|------|-------|-------------|
| **Cursory** | Key files only — controllers, security configs, build files, main `application.properties` | Top 20% of manifest by category relevance |
| **Basic** | All main source files matched by category glob patterns | Full manifest for assigned category |
| **Deep** | All main + test + resource files matched by category glob patterns | Full manifest including test/resources |

Scope is implemented via the **deterministic file manifest** (`file-manifest.json`),
built by the `glob` tool (not LLM guesswork) during Discovery. Each category
subagent receives its file subset from the manifest.

---

## Rigor: Analysis Depth Checklist (by Tier)

### Cursory Rigor

For each assigned file:
1. Grep/scan for **known patterns** from `references/category-guides.md`
2. Flag only the **top 3 most severe** patterns per file
3. Do NOT trace call chains or cross-reference between files
4. Findings capped at 1–3 per category

### Basic Rigor

For each assigned file:
1. **Read the full file** (not just grep hits)
2. Run through the **structured category checklist** (below)
3. Flag every violation with severity per `references/severity-calibration.md`
4. Cross-reference within the same file (e.g., a method's callers within the same class)
5. Findings capped at 3–8 per category

**Category checklists** (from `references/category-guides.md`):
- Security: 10 patterns (hardcoded secrets, CORS, SQL injection, missing auth, CSRF, deserialization, actuator, crypto, security headers, lambda DSL)
- Performance: 7 patterns (N+1, caching, connection pools, blocking in reactive, large objects, unbounded collections, string ops)
- Code Quality: 7 patterns (god classes, circular deps, SOLID, duplication, exception handling, resource leaks, field injection)
- Configuration: 5 patterns (hardcoded env values, missing profiles, @Value vs @ConfigProperties, sensitive defaults, misconfigured beans)
- Dependencies: 6 patterns (known vulns, version conflicts, unnecessary deps, outdated deps, wrong scope, Jackson 3 migration)
- Error Handling: 6 patterns (missing @ExceptionHandler, swallowed exceptions, generic catch, leaking internals, missing retry, no fallback)
- Testing: 7 patterns (missing tests, missing test types, assertion quality, test-only code, hardcoded data, mocking quality, TestRestClient)
- API Design: 9 patterns (REST conventions, status codes, response envelopes, pagination, versioning, input validation, error format, OpenAPI, HTTP clients)

### Deep Rigor

All Basic rigor checks, plus:
1. **Trace call chains** across files (controller → service → repository → external call)
2. **Cross-reference** between categories (e.g., does the security config cover all endpoints listed by API design?)
3. **Test coverage analysis**: for each source class, check if test class exists and what it covers
4. **Dependency graph walk**: trace transitive dependency impact
5. Findings capped at 10–20 per category

---

## Combined Tier Matrix

| Scope →<br>Rigor ↓ | Cursory | Basic | Deep |
|---------------------|---------|-------|------|
| **Cursory** | Quick scan of key files. 1–3 findings/cat. ~2–3 min. | Partial-read of all main files. 3–5 findings/cat. ~5 min. | Partial-read all files incl. tests. 5–8 findings/cat. ~8 min. |
| **Basic** | Full-read key files. 2–4 findings/cat. ~3–4 min. | Full-read all main files. 3–8 findings/cat. ~5–10 min. | Full-read all files. 8–12 findings/cat. ~12–15 min. |
| **Deep** | Deep analysis of key files. 3–5 findings/cat. ~5–7 min. | Deep analysis of all main files. 8–15 findings/cat. ~12–20 min. | Full deep analysis. 10–20 findings/cat. ~15–30+ min. |

**Default mapping:** The `depth` parameter maps to both scope and rigor at the same tier
(e.g., `depth=basic` → Basic scope + Basic rigor). This can be overridden separately
if needed.

---

## Per-Category Limits

| Rigor | Max Findings | Max Words per Finding | Max Files per Subagent |
|-------|-------------|----------------------|----------------------|
| Cursory | 3 | 150 | 30 |
| Basic | 8 | 200 | 100 |
| Deep | 20 | 200 | 250 |

---

## Token Budget & Sharding (Q5)

Before dispatching subagents, estimate the token budget for each category:

1. Sum file sizes (bytes) from the manifest for this category's file subset.
2. Compare against the subagent context window (~100K tokens ≈ 400KB of source).
3. If total bytes exceed 75% of the estimated context window:
   - **Shard the manifest**: split files deterministically (alphabetically, or by
     directory) into N batches, each ≤75% of context window.
   - Dispatch N subagents per category, one per shard. Each writes to the same
     scratchpad file with append semantics.
   - The `.status.json` `token_budget.sharding_required` is set to `true`.
4. If sharding would require more than 4 shards per category AND the project
   has >500 source files:
   - **Auto-degrade the scope tier** to the next level down and warn the user:
     "Project exceeds Deep analysis budget — falling back to Basic scope with
     guaranteed full coverage instead of Deep with partial coverage."
   - This prevents silent partial-coverage analysis.

---

## Triviality Thresholds (Deterministic — Q10)

An application is classified as **trivial** (automatic cursory, no depth prompt) if
ALL of the following are true:

- ≤ 20 Java/Kotlin source files
- ≤ 5 controllers
- ≤ 5 services
- ≤ 3 repositories
- ≤ 3 configuration classes
- NOT a multi-module project
- ≤ 30 direct dependencies

If ANY threshold is exceeded, the project is **non-trivial** and the depth prompt
is shown.

**Regardless of triviality, the chosen depth and rigor are always logged to
`.status.json` with the reason.** Example:
```json
{
  "triviality_reason": "15 source files ≤ 20 threshold, all other metrics below thresholds — automatic cursory",
  "depth": "cursory",
  "rigor": "cursory"
}
```

Parameter override (`depth=basic`) always wins over triviality auto-detection.

---

## sb4-migration Category (conditional)

When active (SB version < 4.0.0 and user opted in), this category runs at a fixed
scope equivalent to Basic and rigor equivalent to Basic, regardless of the chosen
tier. It is a static audit of build files, test annotations, and import
statements — not a deep code analysis.

| Aspect | sb4-migration |
|--------|---------------|
| Files analyzed | Build files, test sources, security configs, all Java imports |
| Rigor | Static audit (grep/pattern match) |
| Findings per cat | 5–15 (depends on project size) |
| Max finding words | 200 |
| Concurrent agents | Included in max_parallel count |