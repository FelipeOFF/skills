# Python (Django + SQLAlchemy) — N+1 Guard
> Prerequisite: read `references/detection-playbook.md` and `references/false-cures-and-gotchas.md`.

Stack tag on the left of each line. Django ORM/DRF and SQLAlchemy 1.4/2.0 (FastAPI/Flask).

## Detect — runtime

**Fail-at-point first** (blows up at the `file:line` of the lazy access):

```python
# SQLAlchemy — raiseload('*') on the SELECT: any non-eager relation raises right there
from sqlalchemy import select
from sqlalchemy.orm import selectinload, raiseload
stmt = select(User).options(selectinload(User.addresses), raiseload('*'))
users = session.scalars(stmt).all()        # user.orders -> InvalidRequestError
```

```python
# SQLAlchemy — mapper default: forbids lazy SELECT everywhere
class User(Base):
    addresses: Mapped[list['Address']] = relationship(lazy='raise_on_sql')
```

```python
# async: a non-eager lazy already raises MissingGreenlet on its own (free tripwire).
# Cure with selectinload — NEVER silence it with session.run_sync.
```

Django has no native fail-at-point equivalent; the closest is
`django-zen-queries` (maintained): anything after `fetch_all()` that fires a query raises.

```python
from zen_queries import queries_disabled, fetch_all
qs = fetch_all(Author.objects.prefetch_related('books'))
with queries_disabled():
    data = AuthorSerializer(qs, many=True).data   # stray query -> QueriesDisabledError
```

**Pattern-detectors / logging hooks:**

```python
# Django — nplusone (canonical, but low-maint 2025-26; confirm against your version)
INSTALLED_APPS += ['nplusone.ext.django']
MIDDLEWARE = ['nplusone.ext.django.NPlusOneMiddleware', *MIDDLEWARE]
NPLUSONE_RAISE = True              # detection becomes a hard failure (great in CI)
```

```python
# SQLAlchemy — native event: is_relationship_load is the exact N+1 signature
@event.listens_for(Session, 'do_orm_execute')
def _watch(state):
    if state.is_relationship_load:                 # lazy load on a loaded obj
        log.warning('possible N+1: %s', state.statement)
```

```python
# Django stdlib (no install) — counts real SQL even with DEBUG=False
from django.db import connection
from django.test.utils import CaptureQueriesContext
with CaptureQueriesContext(connection) as ctx:
    list(AuthorSerializer(Author.objects.all(), many=True).data)
print(len(ctx.captured_queries))
```

Other runtime: Django `pellet` (maintained, X-Pellet-* headers + threshold),
`django-silk`/`django-silky` (N+1 banner), debug-toolbar (Dupl/Sim badges).
SQLAlchemy `query-counter` (tatari-tv, maintained) or `echo=True` to eyeball.

## Detect — static / lint

```bash
# Django — querysets that iterate a relation but never eager-load (instant triage)
grep -rL 'select_related\|prefetch_related' \
  $(grep -rlE '\.objects\.(all|filter)' --include='*.py' .)
```

```bash
# SQLAlchemy — relationship() with no safe strategy (default lazy='select' = risk)
grep -rnE "relationship\(" app/ | grep -vE "lazy=('|\")(raise|selectin|joined|subquery)"
grep -rn "selectinload\|joinedload\|raiseload" app/   # where eager IS already used
```

```yaml
# ast-grep (both) — relation access inside a for: sg scan -r loop.yml .
id: rel-access-in-loop
language: python
rule: { inside: { kind: for_statement }, pattern: $OBJ.$ATTR }
message: relation accessed in loop — confirm eager-load upstream (N+1?)
```

semgrep (`--config nplus1.yml`): rule `query-in-loop` flags
`session.execute/get` or `.objects.filter()` per iteration. Use WARNING in CI;
both false-positive on already eager-loaded loops.

## Fix — eager idioms by cardinality

| Stack · Relation | Idiom | Snippet |
|---|---|---|
| Django · 1:1/FK | `select_related` (JOIN, 1 query) | `Book.objects.select_related('author', 'author__publisher')` |
| Django · 1:N | `prefetch_related` (reverse FK; 2 queries) | `Author.objects.prefetch_related('books')` |
| Django · M:N | `prefetch_related` + `Prefetch()` to filter | `Article.objects.prefetch_related(Prefetch('tags', queryset=Tag.objects.filter(active=True)))` |
| Django · 1:N count | `annotate(Count())` instead of summing in the loop | `Author.objects.annotate(num_books=Count('books'))` |
| Django · GFK | `GenericPrefetch` (`select_related` does NOT work on GFK) | `Comment.objects.prefetch_related(GenericPrefetch('content_object', [Post.objects.all()]))` |
| SQLAlchemy · 1:N | `selectinload` (DEFAULT; IN-batch, no JOIN) | `select(User).options(selectinload(User.addresses))` |
| SQLAlchemy · M:N | `selectinload` (avoids cartesian blowup) | `select(Post).options(selectinload(Post.tags))` |
| SQLAlchemy · 1:1/FK | `joinedload(..., innerjoin=True)` | `select(Address).options(joinedload(Address.user, innerjoin=True))` |
| SQLAlchemy · nested | loader chain | `select(User).options(selectinload(User.orders).selectinload(Order.items))` |

**1:N trap:** eager JOIN (`joinedload` on a collection / `select_related` on a reverse FK)
multiplies rows (cartesian) and breaks `LIMIT`/pagination. For 1:N and M:N ALWAYS
use the 2-query strategy: `prefetch_related` (Django) / `selectinload`
(SQLAlchemy). `joinedload` only for many-to-one / 1:1.

## Guardrail — query-count test assertion

Use **MAX, not exact** (exact flakes with auth/savepoints/warmup and with the
legitimate extra query from `selectinload`/`prefetch`). And run with a **small AND
large** fixture — only a CONSTANT count proves the absence of N+1.

```python
# Django — pytest-django (parametrize row count to prove invariance)
@pytest.mark.django_db
def test_list_constant_queries(client, django_assert_max_num_queries):
    AuthorFactory.create_batch(20)
    with django_assert_max_num_queries(3):     # fixed ceiling despite 20 rows
        assert client.get('/api/authors/').status_code == 200
# stdlib unittest: with self.assertNumQueries(3): ...
```

```python
# SQLAlchemy — homegrown (zero-dep, RECOMMENDED): count via after_cursor_execute
@contextmanager
def assert_max_queries(engine, n):
    q = []
    def cb(conn, cur, stmt, params, ctx, many): q.append(stmt)
    event.listen(engine, 'after_cursor_execute', cb)
    try: yield q
    finally:
        event.remove(engine, 'after_cursor_execute', cb)
        assert len(q) <= n, f'{len(q)} > max {n}:\n' + '\n'.join(q)
```

## Stack gotchas

- **Django:** the fix goes in the ViewSet's `get_queryset()`, **never** in the serializer.
  `SerializerMethodField`/nested serializers traverse relations outside the view
  and are the #1 source of hidden N+1.
- **Django:** `.only()`/`.defer()` then reading the deferred field per row = a new
  N+1. `prefetch_related` followed by `.values()`/`.values_list()`/`.count()`
  bypasses the prefetch cache.
- **Django:** `Count()` over multiple relations in one `annotate()` fans out and
  inflates counts — use `distinct=True` or separate subqueries.
- **Django:** `nplusone` misses queries fired during serialization / on already
  fetched objects — complement with `zen_queries.queries_disabled()`.
- **SQLAlchemy:** `raiseload`/`lazy='raise'` do NOT apply during the unit-of-work
  flush — flush-time N+1 escapes the guard.
- **SQLAlchemy:** `selectinload` emits a SEPARATE query (the counter sees 2, not 1) —
  that is correct, not N+1. Count SHAPES that scale with N, not the raw total.
- **SQLAlchemy:** register the engine listener BEFORE the connection opens — the
  Connection pins its listeners at creation. `subqueryload` is superseded by
  `selectinload`; don't use it by default.
- **SQLAlchemy:** `lazy='joined'` as a global default looks like a fix but causes JOIN
  explosion; `selectin` is the safe default. `raiseload('*')` also blocks
  deferred columns and relations you want lazy — scope it to specific relations.

## LLM playbook (ordered, tool-first)

1. **Inventory.** Django: `grep -rlE 'class .+(ModelViewSet|ListAPIView|ReadOnlyModelViewSet)' --include='*.py' .` and `grep -rn 'SerializerMethodField\|get_queryset' serializers.py views.py`. SQLAlchemy: `grep -rnE "relationship\(" app/` and note the `lazy=` of each relation.
2. **Static triage.** `grep -rL 'select_related\|prefetch_related'` on querysets that iterate (Django); `grep -rn "selectinload\|joinedload\|raiseload" app/` (SQLAlchemy) — relations that never show up are suspects. Run ast-grep/semgrep `rel-access-in-loop`/`query-in-loop`.
3. **Classify each relation.** FK/1:1 -> `select_related`/`joinedload`; reverse-FK/M2M/GFK -> `prefetch_related`/`selectinload`/`GenericPrefetch`; count/sum in a loop -> `annotate(Count())`.
4. **Write the ceiling test FIRST (red).** `django_assert_max_num_queries(N)` or `assert_max_queries(engine, N)`, seeding `create_batch(20+)`. Run it; confirm it FAILS at ~O(rows).
5. **Reproduce the SQL.** Django: `CaptureQueriesContext` or debug-toolbar/silk. SQLAlchemy: `echo=True` and look for the same `SELECT ... WHERE x.id = ?` repeated with different binds.
6. **Confirm precisely.** Django: turn on `NPLUSONE_RAISE=True` (+middleware) or `pellet`. SQLAlchemy: `do_orm_execute` listener + `state.is_relationship_load` (>0 = confirmed, with the statement in hand).
7. **Apply the fix at the query layer.** Django: in `get_queryset()` (not the serializer) — `select_related`/`prefetch_related`/`Prefetch(queryset=..., to_attr=...)`/`annotate`. SQLAlchemy: `.options(selectinload/joinedload(innerjoin=True))`, chain for nested.
8. **Re-run the test (green).** Constant count between `create_batch(20)` and `create_batch(50)`. If it still scales: check false cures (re-filtered prefetch, per-row `.only()`/`.defer()`, `.values()` after prefetch, cartesian `joinedload` JOIN).
9. **Pin the guard.** Django: wrap render in `queries_disabled()` after `fetch_all()`. SQLAlchemy: `raiseload('*')` on the SELECT or `lazy='raise_on_sql'` on the mapper — a future regression raises instead of degrading silently.
10. **CI gate.** Keep the `max_num_queries`/`assert_max_queries` tests; optional `NPLUSONE_RAISE=True` in conftest and/or an advisory semgrep step. Async: treat any `MissingGreenlet` in a test as an N+1 failure. Production: Scout APM / Sentry N+1 detectors.
