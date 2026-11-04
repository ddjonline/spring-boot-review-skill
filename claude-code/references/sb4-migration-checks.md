# Spring Boot 4.x Migration Check Guide

This guide is loaded by the `sb4-migration` category subagent. It runs only when
the detected Spring Boot version is < 4.0.0 and the user opted in.

The subagent must load `references/sb4-starter-migration.md` for the full
starter mapping table.

## Check Categories

### 1. Testing Migration (CRITICAL — compilation will fail in Boot 4.x)

- **`@MockBean` / `@SpyBean`:** Search for `import org.springframework.boot.test.mock.mockito.MockBean` and `import org.springframework.boot.test.mock.mockito.SpyBean`. These are REMOVED in Boot 4.x and will not compile.
  - Replacement: `@MockitoBean` / `@MockitoSpyBean` from `org.springframework.test.context.bean.override.mockito`
  - Severity: CRITICAL (compilation failure on upgrade)
  - Also check: `@MockBean`/`@SpyBean` used in `@Configuration` classes — this pattern is NOT supported by `@MockitoBean`. Flag as HIGH.

- **`@SpringBootTest` without `@AutoConfigureMockMvc`:** Search for `@SpringBootTest` test classes that `@Autowired MockMvc` but lack `@AutoConfigureMockMvc`.
  - In Boot 4.x, `@SpringBootTest` no longer auto-configures MockMvc.
  - Severity: HIGH (`@Autowired` will fail with `NoSuchBeanDefinitionException`)

- **`@SpringBootTest` without `@AutoConfigureTestRestTemplate`:** Search for `@SpringBootTest` classes using `TestRestTemplate` without `@AutoConfigureTestRestTemplate`.
  - Severity: HIGH

- **Missing `@ExtendWith(MockitoExtension.class)`:** Search for test classes using `@Mock` but missing `MockitoExtension`. In Boot 3.x, `MockitoTestExecutionListener` was auto-registered. In Boot 4.x, it's not.
  - Severity: HIGH (NullPointerException at test runtime)

- **`RestTemplate` usage:** Flag as MEDIUM. In Boot 4.x, `RestTemplate` is in maintenance mode. Recommend migrating to `RestClient` or HTTP Service Clients.

### 2. Jackson 3 Migration (CRITICAL for compilation)

- **`com.fasterxml.jackson` imports:** Search for any import starting with `com.fasterxml.jackson`. In Jackson 3 (Boot 4.x default), these must be `tools.jackson`.
  - Severity: CRITICAL (compilation failure in Boot 4.x)
  - Note: Jackson 2 support is available as a deprecated stopgap via `spring-boot-jackson2`

- **`ObjectMapper` usage:** Flag instances of `ObjectMapper`. In Jackson 3, the recommended mapper is `JsonMapper`.
  - Severity: MEDIUM (still works with Jackson 2 shim, but should migrate)

### 3. Spring Security 7 Migration (HIGH — runtime breakage)

- **Method-chaining Security DSL:** Search for `authorizeRequests()` (not `authorizeHttpRequests()`) and `.and()` in security configurations. The lambda DSL is the ONLY supported approach in Security 7.
  - Severity: HIGH (compilation error in Boot 4.x)

- **CSRF for stateless APIs:** If the project uses JWT/OAuth2 stateless authentication, flag the absence of explicit CSRF configuration. In Security 7, CSRF is enabled for ALL endpoints by default including stateless APIs, causing 403s.
  - Severity: HIGH (runtime 403 on all state-changing API calls after upgrade)

### 4. Starter & Dependency Audit

- **Classic aggregate starters:** Search for `spring-boot-starter-web` (should be `spring-boot-starter-webmvc`). Flag as MEDIUM.
  - See `references/sb4-starter-migration.md` for the full mapping.

- **Missing new starters:** After upgrade, beans from these technologies will silently fail to auto-configure:
  - `RestClient` instrumentation needs `spring-boot-starter-restclient`
  - Flyway needs `spring-boot-starter-flyway` (was previously pulled in transitively)
  - OpenTelemetry needs `spring-boot-starter-opentelemetry`
  - Severity: HIGH (silent runtime failure)

- **Undertow usage:** If the build file references Undertow, flag as CRITICAL. Undertow is NOT supported in Boot 4.x (incompatible with Jakarta Servlet 6.1).
  - Severity: CRITICAL (server won't start after upgrade)

### 5. Other Migration Items

- **`javax.*` annotations:** Search for `javax.annotation` and `javax.inject` imports. These must be `jakarta.annotation` and `jakarta.inject`.
  - Severity: CRITICAL (compilation failure)

- **Auto-config class references:** If code references auto-config classes directly (for exclusions), check against the renamed packages in `references/sb4-starter-migration.md`.
  - Severity: MEDIUM

- **`logging.file.*` properties:** Search for `logging.file` or `logging.path` in properties files. These were renamed to `logging.file.name` / `logging.file.path`.
  - Severity: MEDIUM

- **`@EnableRetry`:** If using Spring Retry, check that `@EnableResilientMethods` is present. In Boot 4.x / SF7, retry is built into the framework.
  - Severity: LOW (existing Spring Retry still works)

## Severity Summary for Migration Category

| Check | Severity | Impact on Upgrade |
|-------|----------|-------------------|
| `@MockBean`/`@SpyBean` remaining | CRITICAL | Won't compile |
| `com.fasterxml.jackson` imports | CRITICAL | Won't compile |
| `javax.*` annotations | CRITICAL | Won't compile |
| Undertow server | CRITICAL | Won't start |
| `@Autowired MockMvc` without `@AutoConfigureMockMvc` | HIGH | Test context fails |
| `@Autowired TestRestTemplate` without `@AutoConfigureTestRestTemplate` | HIGH | Test context fails |
| Missing `@ExtendWith(MockitoExtension.class)` | HIGH | NullPointerException |
| Missing new starters (restclient, flyway) | HIGH | Silent bean absence |
| CSRF not configured for stateless API | HIGH | Runtime 403 |
| `.and()` style Security DSL | HIGH | Won't compile |
| Classic aggregate starters | MEDIUM | Deprecated, still functional |
| `ObjectMapper` → `JsonMapper` | MEDIUM | Works via shim |
| `RestTemplate` maintenance mode | MEDIUM | Still functional |
| `logging.file.*` rename | MEDIUM | Silent config miss |