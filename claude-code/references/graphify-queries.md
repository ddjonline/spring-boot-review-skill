# Graphify Query Strategies Per Category

Each category subagent uses these targeted graphify queries instead of reading files directly.
Issue queries one at a time, process results, then move to the next query.

| Category | Graphify Queries |
|----------|------------------|
| security | 1. "Find all authentication, authorization, and input validation code paths. Show hardcoded secrets or tokens in configuration nodes. Map security filter chains and CORS configurations." 2. "Find all endpoints without authorization annotations. Show any disabled CSRF or security features." 3. "Find all cryptographic operations. Identify weak algorithms (MD5, SHA-1, DES) or hardcoded keys." |
| performance | 1. "Find all database query methods, loop constructs over collections, and caching annotations. Identify potential N+1 patterns in service-to-repository call paths." 2. "Show connection pool and thread pool configurations. Find any synchronous blocking calls in async contexts." 3. "Find all collection-returning methods without pagination. Identify large object graphs loaded eagerly." |
| code-quality | 1. "Find god classes (nodes with many connections or methods). Identify deep inheritance chains and circular dependencies between packages." 2. "Show code duplication patterns. Find classes with too many injected dependencies (>8)." 3. "Find SOLID violations: instanceof chains, fat interfaces, concrete class instantiation in services." |
| configuration | 1. "Find all application properties, YAML configurations, @ConfigurationProperties classes. Show relationships between config classes and the beans they define." 2. "Identify hardcoded environment-specific values (URLs, ports, hosts) in properties files." 3. "Find sensitive settings enabled in non-dev profiles: show-sql, debug mode, stacktrace exposure." |
| dependencies | 1. "Extract the full dependency tree from build files. Identify version conflicts between declared and transitive dependencies." 2. "Find dependencies with known vulnerabilities. Flag any outdated major versions." 3. "Identify unused or wrong-scope dependencies. Find runtime deps in compile scope." |
| error-handling | 1. "Find all @ExceptionHandler, @ControllerAdvice classes. Map try-catch patterns across the codebase." 2. "Identify controller methods that call services without surrounding error handling. Find swallowed exceptions (empty catch blocks)." 3. "Find external service calls (HTTP, DB, messaging) without retry or circuit breaker patterns." |
| testing | 1. "Map test-to-source class relationships. Find source classes with no corresponding test file." 2. "Identify test files without meaningful assertions. Find excessively mocked tests (>5 mocks per test class)." 3. "Find missing test types: no @SpringBootTest, no @DataJpaTest, no @WebMvcTest coverage." |
| api-design | 1. "Map all REST endpoints: HTTP methods, paths, request/response types, status codes." 2. "Find inconsistent patterns: mixed verb usage, missing response types, varying error response formats." 3. "Identify missing pagination on collection endpoints. Find endpoints without input validation (@Valid, @NotNull)." |
| sb4-migration | 1. "Find all @MockBean and @SpyBean usage in test and configuration classes. Find @SpringBootTest classes using MockMvc without @AutoConfigureMockMvc." 2. "Find all com.fasterxml.jackson imports, ObjectMapper usage, and javax.annotation/javax.inject imports. Find Undertow references in build files." 3. "Find Security configuration: authorizeRequests() or .and() chaining. Find classic aggregate starters (spring-boot-starter-web vs webmvc). Find missing new starters (restclient, flyway)." |

## Rigor Variations

Graphify query depth is driven by the **rigor** tier (not scope), since graphify queries
search the entire knowledge graph regardless of file count:

- **Cursory:** Run only the first query per category.
- **Basic:** Run queries 1 and 2 per category.
- **Deep:** Run all three queries per category.

Even in graphify mode, cross-reference the file manifest to ensure complete coverage.
If graphify queries don't cover all assigned files from the manifest, read the
uncovered files directly.
