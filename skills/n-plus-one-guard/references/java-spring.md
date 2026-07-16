# Java / Spring Boot (Hibernate/JPA) — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

Fix first: **`JOIN FETCH` / `@EntityGraph` / `@BatchSize`** (per query, never
global EAGER). Hibernate **has no** `raiseload` that aborts at the exact point —
the closest is turning off open-in-view and letting the lazy access throw
`LazyInitializationException` at `file:line`. Caveat: this differs from the
silent N+1 (which, with OSIV on, runs the N selects without error).

## Detect — runtime

**Fail-at-point (the closest the stack offers).** Turn OSIV off in tests; lazy
access outside the session throws `LazyInitializationException` pointing at the line:

```properties
# application-test.properties
spring.jpa.open-in-view=false   # lazy outside session -> exception at exact point
```

Dedicated add-on (throws on detected N+1, **third-party, check maintenance**):
`com.github.yannbriancon:spring-hibernate-query-utils` — annotate the test with
`@NoNPlusOne` or set `hibernate.query.interceptor.error-level=EXCEPTION`.

```java
@Test @NoNPlusOne          // fails with N+1QueryException at the repeated query point
void noNPlusOne() { orderService.findAllWithItems(); }
```

**Counters / logging (confirm the N+1 shape).**

```java
// Hibernate Statistics (zero-dependency); use getPrepareStatementCount for real SQL
Statistics s = emf.unwrap(SessionFactory.class).getStatistics();
s.clear();  orderService.findAllWithItems();
assertThat(s.getPrepareStatementCount()).isEqualTo(1L);  // grows with rows = N+1
```

```yaml
# datasource-proxy via gavlyukovskiy starter (Boot 3 -> :2.0.0) — logs + counts
decorator: { datasource: { datasource-proxy: { count-query: true,
  query: { enable-logging: true, log-level: INFO } } } }
```

Raw eyeball: `spring.jpa.show-sql=true` + `hibernate.format_sql=true` → walls of
near-identical SELECTs. `p6spy-spring-boot-starter:1.9.0` shows SQL with real
params. Both only log — they don't assert.

## Detect — static / lint

```yaml
# Semgrep: EAGER on to-many (classic source of N+1 / cartesian)
rules:
- id: jpa-eager-to-many
  languages: [java]
  severity: WARNING
  patterns:
  - pattern-either:
    - pattern: "@OneToMany(..., fetch = FetchType.EAGER, ...)"
    - pattern: "@ManyToMany(..., fetch = FetchType.EAGER, ...)"
```

```yaml
# ast-grep: repository call INSIDE a loop (the runtime shape of N+1)
rule:
  inside: { any: [ {kind: for_statement}, {kind: enhanced_for_statement} ] }
  pattern: $REPO.$METHOD($$$)
constraints: { METHOD: { regex: "^(find|get|load|count|exists)" } }
```

**ArchUnit** gates CI as a plain JUnit test (fails if any `@OneToMany`/
`@ManyToMany` declares `fetch=EAGER`). **JPA Buddy** (IntelliJ) flags EAGER
to-many at edit-time. SonarQube has no first-class N+1 rule — use a custom Java
rule + Quality Gate.

## Fix — eager idioms by cardinality

| Relation | Idiom | Snippet |
|---|---|---|
| **1:1 · @ManyToOne/@OneToOne (FK)** | Always explicit `LAZY` (default is EAGER → select per row) | `@ManyToOne(fetch = FetchType.LAZY) @JoinColumn(name="customer_id") Customer customer;` |
| **1:N** | Declarative `@EntityGraph` (no join to write) | `@EntityGraph(attributePaths = {"items","items.product"}) @Query("select o from Order o") List<Order> findAllGraph();` |
| **1:N** | `JOIN FETCH` + `distinct` (one collection/query) | `@Query("select distinct o from Order o join fetch o.items where o.status=:st") List<Order> withItems(@Param("st") Status st);` |
| **1:N (join explodes rows)** | `@BatchSize` → N+1 becomes N/size+1 | `@OneToMany(mappedBy="order", fetch=LAZY) @BatchSize(size=25) List<OrderItem> items;` |
| **M:N** | ONE collection via graph; the rest via batch | `@EntityGraph(attributePaths="roles") List<User> findByActiveTrue();` + `hibernate.default_batch_fetch_size=25` |
| **read-only** | DTO projection (sidesteps lazy entirely) | `@Query("select new com.app.OrderView(o.id,o.total,c.name) from Order o join o.customer c") List<OrderView> views();` |

**Cartesian trap (1:N):** `JOIN FETCH` on a to-many duplicates parents — use
`distinct` and it **breaks `setMaxResults`/pagination**. **Two** to-many `JOIN
FETCH` in the same query = `MultipleBagFetchException` or cartesian product: do
one collection per query and batch the rest (`@BatchSize` /
`default_batch_fetch_size`).

## Guardrail — query-count test assertion

Canonical: **hypersistence-utils** — `SQLStatementCountValidator` (counts real
JDBC statements). Pin the artifact to the Hibernate minor:
`-hibernate-62` / `-63` (covers 6.3–6.6) / `-71` / `-73`; the wrong variant
silently no-ops.

```java
import static io.hypersistence.utils.hibernate.util.SQLStatementCountValidator.*;
reset();                              // MANDATORY: thread-local is cumulative
List<Order> o = orderService.findAllWithItems();
assertSelectCount(1);                 // N+1 -> SQLStatementCountMismatchException
```

Param-aware (no hardcoded number) — **QuickPerf** fails when the SAME SELECT runs
with different params, the exact N+1 signature:

```java
@QuickPerfTest class OrderRepoTest {
  @Test @ExpectMaxSelect(2)            // prefer MAX over EXACT (savepoints/warmup flicker)
  @DisableSameSelectTypesWithDifferentParamValues
  void noNPlusOne() { orderService.findAllWithItems(); }
}
```

**Run with a small AND a large fixture**: the N+1 vanishes when the count stays
**constant**, independent of row count. A ceiling that passes only with N=1 hides
the bug. (The maintained QuickPerf SQL starter targets Boot 2; on Boot 3 combine
`quick-perf-junit5` + `quick-perf-sql-annotations` + a datasource-proxy bean, or
stay on hypersistence-utils, which tracks Hibernate 6.x/7.x.)

Per-request counter (per-endpoint ceiling in CI/E2E): an `OncePerRequestFilter`
that reads `QueryCountHolder.grandTotal().getSelect()` and fails above budget —
requires the DataSource wrapped with `ProxyDataSourceBuilder...countQuery()`.

## Stack gotchas

- **`@ManyToOne`/`@OneToOne` default to EAGER** — the most common silent N+1
  source. Only to-many is LAZY by default; force explicit LAZY on to-ones.
- **LAZY on to-one is only a hint** without bytecode enhancement; non-optional
  `@OneToOne` often comes back eager anyway. Don't assume — measure the count.
- **`Statistics.getQueryExecutionCount()` does NOT count lazy-init by-id** (only
  HQL/criteria). Use `getPrepareStatementCount()` or hypersistence/datasource-proxy
  for real SQL counts.
- **OSIV (open-in-view) is ON by default in Boot** and masks N+1: it lazy-loads
  at view render, emitting the N selects **after** the assert window. Turn off
  `spring.jpa.open-in-view=false` in tests to fail fast.
- **False cure: global EAGER** "fixes" one query's count and re-triggers N+1 /
  cartesian in every other query touching the entity. Always per-query.
- **Counters are thread-local and cumulative** — `reset()`/`clear()` right before
  the unit-of-work, else fixture saves inflate the assert.
- `@DisableSameSelectTypesLimit` **does not exist**; the real name is
  `@DisableSameSelectTypesWithDifferentParamValues` (`org.quickperf.sql.annotation`).

## LLM playbook (ordered, tool-first)

1. **Hibernate version:** `grep -RnE 'org\.hibernate|spring-boot-starter-data-jpa' pom.xml build.gradle*` → pick the `hypersistence-utils-hibernate-<ver>` (-62/-63/-71/-73).
2. **Static smell (EAGER trap):** `grep -REn 'FetchType\.EAGER|@ManyToOne|@OneToOne|@OneToMany|@ManyToMany' src/main/java` — flag every `@ManyToOne`/`@OneToOne` without explicit `LAZY`.
3. **Runtime shape (repo call in loop):** ast-grep/semgrep the "repo call inside loop" rule, or `grep -REn 'for |forEach|\.stream\(\)|\.map\(' -A4 src/main | grep -E '\.(find|get|load|count)'`.
4. **Confirm missing eager:** does each suspect method have `JOIN FETCH` / `@EntityGraph` / `@BatchSize`? Absence + lazy access in a loop = high-confidence N+1.
5. **Make it observable:** `application-test.properties` → `spring.jpa.show-sql=true`, `hibernate.generate_statistics=true`, `logging.level.org.hibernate.stat=DEBUG`, `spring.jpa.open-in-view=false`.
6. **Precise counter:** add `io.hypersistence:hypersistence-utils-hibernate-<ver>` in test scope; wrap the call with `reset()` … `assertSelectCount(1)`.
7. **Run the target test:** `./mvnw -Dtest=*RepositoryTest test` (or `./gradlew test --tests '*RepositoryTest'`). `SQLStatementCountMismatchException` with escalating selects = N+1 confirmed.
8. **Dynamic rows → param-aware:** `@QuickPerfTest` + `@DisableSameSelectTypesWithDifferentParamValues` instead of a fixed number.
9. **Per-request guard (E2E/CI):** DataSource with `ProxyDataSourceBuilder...countQuery()` + `OncePerRequestFilter` that fails when `QueryCountHolder.grandTotal().getSelect()` exceeds the endpoint budget.
10. **Fix by cardinality, not blanket EAGER:** 1:N/M:N → `@EntityGraph`/`JOIN FETCH` (distinct) for one collection, `@BatchSize`/`default_batch_fetch_size` for the rest; to-one → `LAZY`; read-only → DTO projection.
11. **Re-run 6–7:** count constant and independent of rows. Confirm you did NOT create a cartesian (two to-many `JOIN FETCH` / `MultipleBagFetchException`).
12. **Lock it in CI:** keep `assertSelectCount`/`@ExpectMaxSelect` as a regression test + ArchUnit "no EAGER to-many" + the eager semgrep rule.
