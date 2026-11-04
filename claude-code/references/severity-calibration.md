# Severity Calibration Examples

Concrete code-level examples used by the scoring subagent to calibrate severity
assignment. These are loaded into the scoring prompt to ensure consistent
severity assignment across re-runs.

---

## CRITICAL (−10 penalty)

**Security vulnerability, data loss risk, production outage risk. Fix immediately.**

### Calibration Examples

1. **Plaintext password in application.properties**
   ```properties
   spring.datasource.password=MySecretP@ssw0rd  # ← CRITICAL
   ```
   Not using jasypt/vault/cloud config for secrets. Replace with `[REDACTED]` in findings.

2. **SQL injection via concatenated query**
   ```java
   @Query("SELECT u FROM User u WHERE u.name = '" + name + "'")  // ← CRITICAL
   ```
   String concatenation in query construction. Must use parameterized queries.

3. **Public endpoint with no authentication or rate limiting**
   ```java
   @PostMapping("/api/admin/users/delete")
   public void deleteUser(@RequestBody DeleteRequest req) { ... }
   // No @PreAuthorize, no security filter, no rate limiter → CRITICAL
   ```

4. **Jackson polymorphic deserialization enabled**
   ```java
   objectMapper.enableDefaultTyping();  // ← CRITICAL
   // OR
   @JsonTypeInfo(use = Id.CLASS)  // ← CRITICAL
   ```
   Known RCE vector. Must never be enabled on untrusted input.

5. **Actuator shutdown endpoint exposed**
   ```properties
   management.endpoint.shutdown.enabled=true  # ← CRITICAL
   ```
   Combined with `management.endpoints.web.exposure.include=*` or missing security.
   Also: CVE-2026-40976 if SB version is 4.0.0–4.0.5 (CVSS 9.1).

6. **Thread.sleep() in @Transactional method**
   ```java
   @Transactional
   public void processOrder() {
       Thread.sleep(5000);  // ← CRITICAL — holds DB connection in transaction
   }
   ```
   Exhausts connection pool under load. Production outage risk.

---

## HIGH (−5 penalty)

**Significant bug, performance degradation, missing critical tests. Fix before next release.**

### Calibration Examples

1. **N+1 query in a hot-path endpoint**
   ```java
   @GetMapping("/orders")
   public List<Order> getOrders() {
       return orderRepository.findAll();  // Each order triggers lazy-load of items → HIGH
   }
   ```
   Use `JOIN FETCH` or `@EntityGraph` to eager-load in single query.

2. **Missing @Transactional on multi-table write**
   ```java
   public void transferFunds(Account from, Account to, BigDecimal amount) {
       accountRepository.save(from.debit(amount));
       accountRepository.save(to.credit(amount));
       // No @Transactional — partial write on failure → HIGH
   }
   ```

3. **Empty catch block swallowing exceptions**
   ```java
   try {
       paymentService.charge(card, amount);
   } catch (Exception e) {
       // Empty — payment failure silently ignored → HIGH
   }
   ```

4. **Unbounded findAll() without pagination**
   ```java
   @GetMapping("/users")
   public List<User> getAllUsers() {
       return userRepository.findAll();  // Returns 100K rows → HIGH
   }
   ```

5. **Missing CSRF configuration in stateless API (Boot ≥ 4.0.0)**
   ```java
   @Bean
   public SecurityFilterChain filterChain(HttpSecurity http) {
       return http.authorizeHttpRequests(auth -> auth.anyRequest().authenticated())
           .oauth2ResourceServer(oauth2 -> oauth2.jwt(Customizer.withDefaults()))
           .build();
       // Missing csrf(csrf -> csrf.disable()) → HIGH — runtime 403s on POST/PUT/DELETE
   }
   ```

6. **Core business logic with no test**
   ```java
   public class PricingEngine {
       public BigDecimal calculatePrice(Order order) { ... }
   }
   // No PricingEngineTest.java exists → HIGH
   ```
   Test coverage < 30% on the package containing this class.

---

## MEDIUM (−2 penalty)

**Code smell, minor performance issue, inconsistent pattern. Fix in current sprint.**

### Calibration Examples

1. **Missing @Cacheable on read-heavy method**
   ```java
   public Product getProduct(Long id) {
       return productRepository.findById(id).orElseThrow();
       // Called on every page render, data changes rarely → MEDIUM
   }
   ```

2. **Controller returning 200 OK for all responses**
   ```java
   @PostMapping("/users")
   public ResponseEntity<User> createUser(@RequestBody User user) {
       return ResponseEntity.ok(userService.create(user));  // Should be 201 Created → MEDIUM
   }
   ```

3. **Dependency version 2+ minor versions behind**
   ```xml
   <parent>
       <groupId>org.springframework.boot</groupId>
       <artifactId>spring-boot-starter-parent</artifactId>
       <version>3.2.0</version>  <!-- Latest is 4.1.x → MEDIUM -->
   </parent>
   ```

4. **God class with 15+ injected dependencies**
   ```java
   @Service
   public class OrderService {
       // 18 @Autowired fields → MEDIUM (500-1000 lines also triggers this)
   }
   ```
   Below 8 dependencies: no flag. 8-14: LOW. 15+: MEDIUM. 20+: HIGH.

5. **Missing input validation on internal endpoint**
   ```java
   @PostMapping("/internal/reports")
   public Report generateReport(@RequestBody ReportRequest req) {
       // No @Valid, not public-facing, but still should validate → MEDIUM
   }
   ```
   If this were public-facing, severity would be HIGH.

---

## LOW (−1 penalty)

**Style issue, missing documentation, improvement suggestion. Address when convenient.**

### Calibration Examples

1. **Field injection instead of constructor injection**
   ```java
   @Service
   public class UserService {
       @Autowired
       private UserRepository userRepository;  // Use constructor injection → LOW
   }
   ```

2. **Missing OpenAPI/Swagger documentation**
   ```java
   @RestController
   public class UserController {
       // No @Tag, @Operation, @ApiResponses annotations → LOW
   }
   ```

3. **Unused dependency in build file**
   ```xml
   <dependency>
       <groupId>org.springframework.boot</groupId>
       <artifactId>spring-boot-starter-data-jpa</artifactId>
   </dependency>
   <!-- No JPA entities or repositories found → LOW -->
   ```

4. **String concatenation in loop without StringBuilder**
   ```java
   String result = "";
   for (Item item : items) {
       result += item.getName() + ",";  // Use StringBuilder → LOW
   }
   ```

5. **Multiple @Value annotations where @ConfigurationProperties would be cleaner**
   ```java
   @Value("${app.email.from}")
   private String from;
   @Value("${app.email.subject}")
   private String subject;
   // 5+ @Value fields — bundle into @ConfigurationProperties → LOW
   ```

---

## INFO (0 penalty)

**Observation. No action required. For awareness only.**

### Calibration Examples

1. **RestTemplate usage in Boot ≥ 4.0.0 (maintenance mode)**
   ```java
   RestTemplate restTemplate = new RestTemplate();
   // INFO: "RestTemplate is in maintenance mode. Consider HTTP Service Clients."
   ```

2. **TestRestClient adoption available**
   ```java
   @SpringBootTest(webEnvironment = WebEnvironment.RANDOM_PORT)
   class UserControllerTest {
       @Autowired
       private TestRestTemplate restTemplate;
       // INFO: "Consider RestTestClient for fluent API across mock and real server tests."
   }
   ```

---

## Boundary Cases: Decision Rules

When a finding falls between two severity levels, use these tiebreakers:

| Scenario | Decision Rule | Rationale |
|----------|---------------|-----------|
| Security vs. non-security | Security impact → prefer higher severity | Security issues have higher blast radius |
| Public vs. internal endpoint | Public → +1 severity | Public endpoints are directly attackable |
| Hot path vs. cold path | Hot path (called per-request) → +1 severity | Higher blast radius under load |
| Has test vs. no test | No test → +1 severity | Cannot verify behavior; unknown risk |
| Compile failure vs. runtime | Compile failure → CRITICAL | Blocks deployment |
| Config only vs. code change | Config fix → prefer lower severity | Config is easier to fix |
| Spring Boot ≥ 4.0.0 vs < 4.0.0 | Version-specific guidance takes precedence | See category-guides.md for version-dependent checks |