# Spring Boot 4.x Starter Migration Mapping

This reference maps classic Spring Boot 3.x starter dependencies to their
Spring Boot 4.x equivalents. The monolithic `spring-boot-autoconfigure`
jar was split into per-technology modules. Classic aggregate starters
are deprecated but still work as a transition aid.

## Starter Mapping Table

| Spring Boot 3.x Starter | Spring Boot 4.x Equivalent | Notes |
|--------------------------|---------------------------|-------|
| `spring-boot-starter-web` | `spring-boot-starter-webmvc` | Renamed; aggregate deprecated |
| (none) | `spring-boot-starter-restclient` | **New** — required for RestClient/RestTemplate auto-config |
| (none) | `spring-boot-starter-webclient` | **New** — required for WebClient auto-config (WebFlux) |
| `spring-boot-starter-data-jpa` | `spring-boot-starter-data-jpa` | Unchanged |
| `spring-boot-starter-data-mongodb` | `spring-boot-starter-mongodb` | Renamed; health indicators moved |
| `spring-boot-starter-security` | `spring-boot-starter-security` | Unchanged |
| `spring-boot-starter-actuator` | `spring-boot-starter-actuator` | Unchanged |
| `spring-boot-starter-validation` | `spring-boot-starter-validation` | Unchanged |
| `spring-boot-starter-test` | `spring-boot-starter-test` | Unchanged; `MockitoExtension` must be explicit |
| (none) | `spring-boot-starter-webmvc-test` | **New** — test companion for webmvc |
| (none) | `spring-boot-starter-restclient-test` | **New** — test companion for restclient |
| (none) | `spring-boot-starter-webclient-test` | **New** — test companion for webclient |
| `spring-boot-starter-actuator` (test) | `spring-boot-starter-actuator-test` | **New** — test companion |
| `spring-boot-starter-oauth2-client` | `spring-boot-starter-oauth2-client` | Unchanged |
| `spring-boot-starter-oauth2-resource-server` | `spring-boot-starter-oauth2-resource-server` | Unchanged |
| `spring-boot-starter-cache` | `spring-boot-starter-cache` | Unchanged |
| `spring-boot-starter-quartz` | `spring-boot-starter-quartz` | Unchanged |
| `spring-boot-starter-mail` | `spring-boot-starter-mail` | Unchanged |
| `spring-boot-starter-amqp` | `spring-boot-starter-amqp` | Unchanged |
| `spring-boot-starter-kafka` | `spring-boot-starter-kafka` | Unchanged |
| (none) | `spring-boot-starter-opentelemetry` | **New** — OTEL metrics + traces |
| `spring-boot-starter-batch` | `spring-boot-starter-batch` | Unchanged |
| (none) | `spring-boot-kotlin-serialization` | **New** — Kotlin serialization support |
| `spring-boot-starter-flyway` | `spring-boot-starter-flyway` | Unchanged (was previously auto-configured from web starter) |
| `spring-boot-starter-data-redis` | `spring-boot-starter-data-redis` | Unchanged |

## Renamed Auto-Configuration Packages

When auto-config classes moved modules, their packages changed. If you
reference auto-config classes directly in exclusions or conditions:

| Spring Boot 3.x Class | Spring Boot 4.x Class |
|----------------------|----------------------|
| `org.springframework.boot.autoconfigure.web.servlet.WebMvcAutoConfiguration` | `org.springframework.boot.webmvc.autoconfigure.WebMvcAutoConfiguration` |
| `org.springframework.boot.autoconfigure.data.mongo.MongoDataAutoConfiguration` | `org.springframework.boot.mongodb.autoconfigure.MongoAutoConfiguration` |
| `org.springframework.boot.autoconfigure.data.redis.RedisAutoConfiguration` | `org.springframework.boot.redis.autoconfigure.RedisAutoConfiguration` |

## Silent Breakage Risks

These changes do NOT cause compilation errors but will break at runtime:

| Risk | Symptom | Fix |
|------|---------|-----|
| Missing `spring-boot-starter-restclient` | `RestClient.Builder` lacks observation instrumentation | Add the starter |
| Missing `spring-boot-starter-flyway` | Flyway migrations silently stop running | Add the starter explicitly |
| Missing `-test` companion starter | Test auto-config beans not available | Add the test companion starter |
| Classic aggregate starter (e.g., `spring-boot-starter-web`) | Still works in 4.x but deprecated; will be removed | Migrate to `spring-boot-starter-webmvc` |
| `logging.file.*` properties | Moved to `logging.file.name` / `logging.file.path` | Update property names |
| `@MockBean` / `@SpyBean` | Compilation error (removed) | Migrate to `@MockitoBean` / `@MockitoSpyBean` |
| `@SpringBootTest` without `@AutoConfigureMockMvc` | `MockMvc` not auto-configured; `@Autowired` fails | Add `@AutoConfigureMockMvc` |
| `@SpringBootTest` without `@AutoConfigureTestRestTemplate` | `TestRestTemplate` not available | Add `@AutoConfigureTestRestTemplate` |
| `MockitoExtension` not registered | `@Mock` fields are null | Add `@ExtendWith(MockitoExtension.class)` |
| Jackson 2 imports (`com.fasterxml.jackson`) | Compilation error in Boot 4.x | Migrate to `tools.jackson` |
| Undertow server | Not supported (incompatible with Servlet 6.1) | Migrate to Tomcat or Jetty |

## Deprecated in Spring Boot 4.x

These still work but should be migrated:

| Item | Replacement |
|------|------------|
| Jackson 2 (`spring-boot-jackson2`) | Jackson 3 (default in Boot 4) |
| `ObjectMapper` | `JsonMapper` |
| `TestRestTemplate` | `RestTestClient` |
| `RestTemplate` (maintenance mode) | `RestClient` or HTTP Service Clients |
| Classic aggregate starters | Modular per-technology starters |
| `AntPathMatcher` | `PathPattern` |
| `javax.annotation` / `javax.inject` | `jakarta.annotation` / `jakarta.inject` |