# Category Analysis Guides

Detailed patterns, anti-patterns, and detection strategies for each analysis
category. These are loaded by subagents to guide their analysis.

---

## Security

**Version awareness:** The application is running Spring Boot {SB_VERSION}.
Some checks below differ based on whether this is < 4.0.0 or ≥ 4.0.0.

### Patterns to Find

1. **Hardcoded Secrets / Credentials**
   - Look for: `password`, `secret`, `apiKey`, `token`, `private.*key` in `application.properties`, `application.yml`, and Java source files
   - Flag any value that appears to be a real credential (not a placeholder like `changeme` or `${...}`)
   - Severity: CRITICAL if real credential found, HIGH if suspect
   - **Never reproduce actual values in findings — use `[REDACTED]`**

2. **Missing or Misconfigured CORS**
   - Look for: `@CrossOrigin(origins = "*")`, `WebMvcConfigurer.addCorsMappings` with `allowedOrigins("*")`
   - Flag: origins set to `*` in non-development profiles
   - Severity: HIGH

3. **SQL/NoSQL Injection Risk**
   - Look for: string concatenation in `@Query`, raw JDBC queries, `String.format` in query strings
   - Flag: any dynamic query construction that isn't using parameterized queries or an ORM
   - Severity: CRITICAL

4. **Missing Authentication/Authorization**
   - Look for: endpoints without `@PreAuthorize`, `@Secured`, or security filter coverage
   - Flag: administrative or data-mutating endpoints with no auth checks
   - Severity: CRITICAL

5. **CSRF Protection — version-dependent (see below)**
   - **Boot ≥ 4.0.0 + stateless API (JWT/OAuth2):** If no explicit CSRF configuration exists, flag as HIGH — Security 7 enables CSRF for ALL endpoints by default, including stateless APIs, causing runtime 403s. The fix is `csrf(csrf -> csrf.disable())` **scoped to the stateless chain only**.
   - **Boot ≥ 4.0.0 + session-based browser app:** CSRF should remain enabled. Flag `csrf().disable()` in session-authenticated chains as HIGH.
   - **Boot < 4.0.0:** Look for `csrf().disable()` in SecurityConfig. Severity: HIGH (if disabled in non-API contexts), MEDIUM (for pure REST APIs with token auth).

6. **Insecure Deserialization**
   - Look for: `ObjectInputStream`, `readObject`
   - **Jackson RCE vector (CRITICAL regardless of version):** Search for `activateDefaultTyping()`, `@JsonTypeInfo(use = Id.CLASS)`, `enableDefaultTyping()`. These enable polymorphic deserialization — a known RCE vector. Flag as CRITICAL in all versions.
   - **Jackson 3 migration:** If SB version ≥ 4.0.0, flag remaining `com.fasterxml.jackson` imports as HIGH (deprecated, will be removed).

7. **Actuator Endpoint Exposure**
   - Look for: `management.endpoints.web.exposure.include=*`, missing actuator security
   - **CVE-2026-40976 (CRITICAL):** If SB version is 4.0.0–4.0.5 and actuator is on the classpath, flag as CRITICAL regardless of config. This CVE (CVSS 9.1) can expose actuator even when configured not to. Mitigation: upgrade to ≥ 4.0.6 or set `management.server.port` to a separate internal port.
   - **Boot ≥ 4.0.6:** Check for separate management port (`management.server.port`). Missing separate port → MEDIUM.
   - **All versions:** `exposure.include=*` → HIGH. Exposed `env`, `heapdump`, `shutdown` → CRITICAL.

8. **Weak Cryptography**
   - Look for: `MD5`, `SHA-1`, `DES`, hardcoded IVs, short key lengths
   - Severity: HIGH

9. **Missing Security Headers**
   - Look for: absence of `X-Content-Type-Options`, `X-Frame-Options`, `Strict-Transport-Security` headers
   - **Content-Security-Policy:** Spring Security does NOT set a CSP header by default. Flag absence as MEDIUM.
   - Severity: MEDIUM

10. **Security 7 Lambda DSL (Boot ≥ 4.0.0 only)**
    - Look for: `authorizeRequests()` (not `authorizeHttpRequests()`) or `.and()` method chaining in security configs. In Security 7, only the lambda DSL is supported.
    - Severity: HIGH if found (won't compile on upgrade)

---

## Performance

### Patterns to Find

1. **N+1 Query Patterns**
   - Look for: `@OneToMany`/`@ManyToOne` with `FetchType.EAGER`, loops calling repository methods, missing `@EntityGraph` or JOIN FETCH
   - Severity: HIGH (if in hot path), MEDIUM (otherwise)

2. **Missing Caching**
   - Look for: absence of `@Cacheable` on read-heavy service methods, no cache configuration
   - Flag: methods that query database on every request when data is relatively static
   - Severity: MEDIUM

3. **Connection Pool Sizing**
   - Look for: `spring.datasource.hikari.maximum-pool-size`, default values without tuning
   - Flag: pool sizes that don't match expected concurrency
   - Severity: MEDIUM

4. **Synchronous Blocking in Reactive Stacks**
   - Look for: `block()`, `subscribe()` in WebFlux/MVC async controllers
   - Severity: HIGH

5. **Large Object Loading**
   - Look for: `SELECT *` on tables with large columns, missing `@Basic(fetch = LAZY)`
   - Severity: MEDIUM

6. **Unbounded Collections**
   - Look for: `findAll()` without pagination, `List<>` returns without `Page<>`
   - Severity: HIGH

7. **Inefficient String Operations**
   - Look for: `+` concatenation in loops, missing `StringBuilder`
   - Severity: LOW

---

## Code Quality

### Patterns to Find

1. **God Classes**
   - Look for: classes >500 lines, classes with >15 methods, classes with >10 injected dependencies
   - Severity: HIGH (if >1000 lines or >20 methods), MEDIUM (500-1000 lines)

2. **Circular Dependencies**
   - Look for: A → B → A injection patterns
   - Flag: `@Lazy` annotations used to break circular deps (indicates the circle exists)
   - Severity: HIGH

3. **SOLID Violations**
   - **Single Responsibility:** classes doing multiple unrelated things
   - **Open/Closed:** `instanceof` chains, type-switching without polymorphism
   - **Liskov:** subclasses that throw `UnsupportedOperationException`
   - **Interface Segregation:** fat interfaces with methods not used by all implementors
   - **Dependency Inversion:** direct instantiation of low-level classes with `new`
   - Severity: MEDIUM

4. **Code Duplication**
   - Look for: identical or near-identical blocks >10 lines across files
   - Severity: MEDIUM

5. **Exception Handling Anti-patterns**
   - Look for: `catch (Exception e) {}` (empty), `e.printStackTrace()`, throwing `Exception` (not specific)
   - Severity: HIGH

6. **Resource Leaks**
   - Look for: unclosed streams/connections without try-with-resources
   - Severity: HIGH

7. **Constructor/Method Injection over Field Injection**
   - Look for: `@Autowired` on fields vs. constructor injection
   - Severity: LOW (preference, not a bug)

---

## Configuration

### Patterns to Find

1. **Hardcoded Environment-Specific Values**
   - Look for: URLs, ports, hosts, paths in `application.properties` without profile variants
   - Severity: MEDIUM

2. **Missing Profiles**
   - Look for: only `application.properties` without `application-dev.yml`, `application-prod.yml`, etc.
   - Severity: MEDIUM

3. **`@ConfigurationProperties` vs. `@Value`**
   - Look for: many `@Value` annotations where a `@ConfigurationProperties` class would be cleaner
   - Severity: LOW

4. **Sensitive Defaults in Production**
   - Look for: `spring.jpa.show-sql=true`, `server.error.include-stacktrace=always`, `debug=true`
   - Flag: if these appear in non-dev profiles
   - Severity: HIGH

5. **Unused or Misconfigured Beans**
   - Look for: `@Bean` methods that duplicate auto-configuration, custom configs that override defaults unnecessarily
   - Severity: LOW

---

## Dependencies

**Version awareness:** The application is running Spring Boot {SB_VERSION}.

### Patterns to Find

1. **Known Vulnerable Dependencies**
   - Check: dependency versions against known CVEs (use `mvn dependency:tree` or `gradle dependencies`)
   - Look for: Spring4Shell, Log4Shell, SnakeYAML deserialization CVEs
   - **CVE-2026-40976:** If SB version is 4.0.0–4.0.5, flag as CRITICAL — upgrade to ≥ 4.0.6
   - Severity: CRITICAL

2. **Version Conflicts**
   - Look for: mismatched Spring Boot starter versions, conflicting transitive deps
   - Flag: `<exclusions>` in Maven or `exclude` in Gradle (symptom of conflicts)
   - Severity: MEDIUM

3. **Unnecessary Dependencies**
   - Look for: starter dependencies that aren't used (e.g., `spring-boot-starter-data-jpa` but no JPA entities)
   - Severity: LOW

4. **Outdated Dependencies**
   - Look for: versions significantly behind latest stable release
   - Flag: Spring Boot version >2 minor versions behind
   - Severity: MEDIUM

5. **Wrong Dependency Scope**
   - Look for: runtime deps declared as compile, test deps in compile scope
   - Severity: LOW

6. **Jackson 3 Migration (version-dependent)**
   - **Boot ≥ 4.0.0:** Flag remaining `com.fasterxml.jackson` imports as HIGH — Jackson 3 is the default (package `tools.jackson`). Jackson 2 support is deprecated.
   - **Boot < 4.0.0:** Flag `com.fasterxml.jackson` usage as MEDIUM — will need migration to `tools.jackson` on upgrade. Note that `ObjectMapper` should become `JsonMapper`.

---

## Error Handling

**Version awareness:** The application is running Spring Boot {SB_VERSION}.

### Patterns to Find

1. **Missing `@ExceptionHandler` / `@ControllerAdvice`**
   - Look for: controllers that throw exceptions without global handling
   - Severity: MEDIUM

2. **Swallowed Exceptions**
   - Look for: `catch (Exception e) { log.error(...) }` without re-throwing or handling
   - Look for: empty catch blocks
   - Severity: HIGH

3. **Generic Exception Catch**
   - Look for: `catch (Exception e)` or `catch (Throwable t)` too broadly
   - Severity: MEDIUM

4. **Leaking Internals in Error Responses**
   - Look for: `e.getMessage()` or `e.getStackTrace()` in API responses
   - Severity: HIGH

5. **Missing Retry / Resilience Patterns — version-dependent**
   - **Boot ≥ 4.0.0 (Spring Framework 7):** Check for `@EnableResilientMethods` on a `@Configuration` class. If absent, flag as MEDIUM. Look for external service calls without `@Retryable` or `@ConcurrencyLimit` — these are built into the framework with no extra dependencies. Recommend adding `@Retryable(maxRetries = 3, delay = 200, multiplier = 2, jitter = 50)` on idempotent external calls. For circuit breaker, Resilience4j is still the standard choice.
   - **Boot < 4.0.0:** Look for external service calls without `@Retryable` (Spring Retry), `@CircuitBreaker` (Resilience4j), or equivalent. Flag as MEDIUM.
   - **All versions:** HTTP calls, database calls, message queue sends without resilience patterns → MEDIUM.

6. **No Fallback for External Calls**
   - Look for: REST template/WebClient calls without `onErrorReturn`/fallback or `@Recover` method
   - Severity: MEDIUM

---

## Testing

**Version awareness:** The application is running Spring Boot {SB_VERSION}.
Configuration-only migration checks (e.g., `@MockBean` → `@MockitoBean`) are handled
by the `sb4-migration` category if active. This category focuses on test quality.

### Patterns to Find

1. **Missing Tests**
   - Cross-reference: source classes vs. test classes
   - Flag: service classes, utility classes, or components with no corresponding test
   - Severity: HIGH (for critical business logic), MEDIUM (otherwise)

2. **Missing Test Types**
   - Look for: only unit tests, no integration tests (`@SpringBootTest`)
   - Look for: no repository tests (`@DataJpaTest`)
   - Look for: no controller tests (`@WebMvcTest`)
   - Severity: MEDIUM

3. **Assertion Quality**
   - Look for: tests without assertions, `assertTrue(true)` stubs
   - Look for: only `assertNotNull` without behavioral assertions
   - Severity: HIGH (no assertions), MEDIUM (weak assertions)

4. **Test-Only Code**
   - Look for: `@VisibleForTesting`, `@TestOnly`, methods/comments suggesting code exists only for tests
   - Flag: production code modified to accommodate tests
   - Severity: MEDIUM

5. **Hardcoded Test Data**
   - Look for: magic strings/numbers in tests without constants or parameterized tests
   - Severity: LOW

6. **Mocking Quality**
   - Look for: `@MockitoBean` used excessively (indicates tight coupling). Note: `@MockBean` usage is flagged by the `sb4-migration` category if active.
   - Look for: mocks that don't verify behavior
   - Severity: LOW

7. **TestRestClient Adoption (Boot ≥ 4.0.0 only)**
   - Flag `TestRestTemplate` usage as INFO — "Consider migrating to `RestTestClient` for a fluent API that works across mock and real server tests."
   - Flag absence of `@AutoConfigureRestTestClient` in integration tests as INFO.
   - **Boot < 4.0.0:** Skip this check.

---

## API Design

**Version awareness:** The application is running Spring Boot {SB_VERSION}.

### Patterns to Find

1. **Inconsistent REST Conventions**
   - Look for: mixed verb usage (GET for mutations, POST for queries)
   - Look for: inconsistent path patterns (`/users`, `/getUsers`, `/api/users`)
   - Severity: MEDIUM

2. **Missing HTTP Status Codes**
   - Look for: all endpoints returning 200 OK (including errors)
   - Look for: no use of 201 Created, 204 No Content, 400/404/409
   - Severity: MEDIUM

3. **No Response Envelope Consistency**
   - Look for: some endpoints return raw entities, others wrap in `ResponseEntity`
   - Severity: LOW

4. **Missing Pagination**
   - Look for: `List<>` return types on collection endpoints without `Page<>`
   - Severity: MEDIUM

5. **No API Versioning Strategy**
   - Look for: no version in path (`/v1/`) or header-based versioning
   - **Boot ≥ 4.0.0:** Built-in API versioning is available via `spring.mvc.apiversion.*`. This is NOT required — many valid alternatives exist. Skip this check unless versioning is clearly needed.
   - Severity: LOW (for greenfield), MEDIUM (for production APIs with known consumers)

6. **Missing Input Validation**
   - Look for: controller parameters without `@Valid`, `@NotNull`, `@NotBlank`
   - Severity: MEDIUM

7. **Inconsistent Error Response Format**
   - Look for: different error structures across controllers
   - Severity: LOW

8. **Missing OpenAPI/Swagger Documentation**
   - Look for: no `springdoc-openapi` dependency, no API annotations
   - Severity: LOW

9. **HTTP Service Clients (Boot ≥ 4.0.0 only)**
   - Check: if `RestClient` is constructed manually via `.create()` or verbose call chains, flag as INFO — "Consider migrating to HTTP Service Clients (`@HttpExchange` interfaces) to reduce boilerplate and enable automatic observability instrumentation."
   - Check: if `RestTemplate` is still in use, flag as INFO — "RestTemplate is in maintenance mode. Consider migrating to HTTP Service Clients."
   - **Boot < 4.0.0:** Skip this check.

---

## Severity Assignment Rules

| Severity  | When to Use |
|-----------|-------------|
| **CRITICAL** | Security vulnerability with exploit potential. Data loss risk. Production outage risk. Known CVE with active exploits. |
| **HIGH** | Significant bug that will cause incorrect behavior. Performance issue in hot path. Missing critical test coverage for core logic. |
| **MEDIUM** | Code smell with practical consequences. Missing non-critical patterns. Inconsistency that causes maintenance burden. |
| **LOW** | Style preference. Missing documentation. Minor improvement opportunity. |
| **INFO** | Observation. No action required. Context for the reviewer. |

**For concrete code-level examples of each severity, see `references/severity-calibration.md`.**
The calibration document is the authoritative reference for the scoring phase.
It includes boundary case decision rules for findings that fall between two
severity levels.