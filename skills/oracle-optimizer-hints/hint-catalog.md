# Oracle Optimizer Hint Catalog

Every **documented** hint in the Oracle SQL Language Reference (19c
baseline, with 21c / 23ai / 26ai changes), plus the undocumented hints you
will meet in outlines, blogs and legacy code. Part of the
[`oracle-optimizer-hints`](SKILL.md) skill — read the skill first for the
decision workflow; this file is the lookup table.

> **Note:** hints are case-insensitive. Oracle's documentation writes them
> in uppercase, so this catalog does too when naming them. Our code standard
> writes them in lowercase like every other keyword — see
> [`sql-format.md`](../../rules/sql-format.md) §13.

---

## How to read the tables

**Syntax** uses the official grammar:

- `tablespec` is the table **alias** exactly as it appears in the query
  block (never `schema.table`). It can use dot notation into a view,
  `view.alias`, which Oracle calls a *global hint*.
- `indexspec` is either an index name or a parenthesised column list —
  `(col1 col2)`. The column form picks any index whose leading columns match,
  so it survives an index rename.
- `@queryblock` targets a query block from outside it — a system-generated
  name like `SEL$2`, or a name you set with `QB_NAME`.

**Since** is `V$SQL_HINT.VERSION`: the release in which the hint first
existed, which can be earlier than the release that documented it.

**CBO** means `V$SQL_HINT.PROPERTY` bit 16 is set. These are the hints
that the `IGNORE_OPTIM_EMBEDDED_HINTS` hint (the SQL Patch "switch hints
off" trick) disables. Behavioural hints (`APPEND`, `RESULT_CACHE`,
`DRIVING_SITE`, `MONITOR`, the parallel family and so on) are **not** in
this class.

**Team use** is our verdict for APEX / PL/SQL application code:

| Verdict | Meaning |
|---|---|
| **Allowed** | Changes *how* a statement executes or loads rather than which plan the optimizer picks, or states an intent the optimizer cannot know. Commit it with a justification comment. |
| **Last resort** | Plan-shaping. Only after the root-cause fixes in the skill's Step 3 have failed, with plan evidence, and as a *complete* hint set. Prefer delivering it with a SQL Patch or SQL Plan Baseline over editing application code. |
| **Diagnostic** | Use while investigating. Never commit it. |
| **Niche** | Valid, but tied to a feature most APEX apps don't use (star schemas, In-Memory, XML DB, multitenant root queries, Exadata zone maps, data mining, vector search). Use it only when that feature is actually in play. |
| **Avoid** | Deprecated, undocumented, superseded, or a trap. |

---

## Optimization goals and approaches

| Hint | Syntax | What it does | Inverse | Since | CBO | Team use |
|---|---|---|---|---|---|---|
| ALL_ROWS | `all_rows` | Optimize the statement block for throughput (minimum total resources). This is already the default mode. | — | 8.1 | yes | Last resort |
| FIRST_ROWS | `first_rows(n)` | Optimize to return the first *n* rows fastest, for a top-N list or a dashboard. It can't help when the plan must sort or aggregate every row before the first one comes back, and it is ignored in `update`/`delete`. | — | 8.1 | yes | Allowed |
| OPTIMIZER_FEATURES_ENABLE | `optimizer_features_enable('19.1.0')` | Revert the optimizer to an older release's behaviour for one statement. This is the standard triage for a plan regression after an upgrade. | — | 10.1 | yes | Last resort (temporary) |
| OPT_PARAM | `opt_param('optimizer_index_cost_adj' 20)` | Set an optimizer parameter for one statement. The documented list covers only `APPROX_FOR_AGGREGATION`, `APPROX_FOR_COUNT_DISTINCT`, `APPROX_FOR_PERCENTILE`, `OPTIMIZER_DYNAMIC_SAMPLING`, `OPTIMIZER_INDEX_CACHING`, `OPTIMIZER_INDEX_COST_ADJ` and `STAR_TRANSFORMATION_ENABLED`. 19c also listed `OPTIMIZER_SECURE_VIEW_MERGING`; the 26ai docs drop it. String values take quotes, numbers don't. | — | 10.2 | yes | Last resort |

> **Note:** `opt_param('_fix_control' '…')` and other hidden (`_`)
> parameters work but are undocumented. Use them for diagnosis only, and
> keep them out of committed code.

---

## Access paths

| Hint | Syntax | What it does | Inverse | Since | CBO | Team use |
|---|---|---|---|---|---|---|
| FULL | `full([@qb] tablespec)` | Full table scan. On an index-organized table it can't apply, because there is no table. | — | 8.1 | yes | Last resort |
| INDEX | `index([@qb] tablespec [indexspec…])` | Index scan (B-tree, bitmap, function-based, domain). With one index, only that index is considered. With a list, the cheapest of the list. With none, the cheapest index. Never a full scan. | NO_INDEX | 8.0 | yes | Last resort |
| NO_INDEX | `no_index([@qb] tablespec [indexspec…])` | Exclude the listed indexes, or all indexes if none are listed. If it names the same index as an `INDEX*` hint, **both** are ignored. | INDEX | 8.1.5 | yes | Last resort |
| INDEX_ASC | `index_asc([@qb] tablespec [indexspec…])` | Index range scan in ascending order. This is the default, so it adds nothing beyond `INDEX`. | NO_INDEX | 8.1 | yes | Avoid (redundant) |
| INDEX_DESC | `index_desc([@qb] tablespec [indexspec…])` | Descending index range scan. Order is only per partition on partitioned indexes. | NO_INDEX | 8.1 | yes | Avoid — write `order by … desc fetch first n rows only` and let the optimizer pick the scan |
| INDEX_COMBINE | `index_combine([@qb] tablespec [indexspec…])` | Combine indexes via bitmap operations. Every listed legal index is used regardless of cost. | — | 8.1 | yes | Last resort |
| INDEX_JOIN | `index_join([@qb] tablespec [indexspec…])` | Answer the query by hash-joining indexes that together contain every needed column. | — | 8.1.5 | yes | Last resort |
| INDEX_FFS | `index_ffs([@qb] tablespec [indexspec…])` | Fast full index scan instead of a full table scan. | NO_INDEX_FFS | 8.1 | yes | Last resort |
| NO_INDEX_FFS | `no_index_ffs([@qb] tablespec [indexspec…])` | Exclude a fast full scan of the listed indexes. | INDEX_FFS | 10.1 | yes | Last resort |
| INDEX_SS | `index_ss([@qb] tablespec [indexspec…])` | Index skip scan, used when the leading index column isn't in the predicate. | NO_INDEX_SS | 9.0 | yes | Last resort |
| INDEX_SS_ASC / INDEX_SS_DESC | `index_ss_desc([@qb] tablespec [indexspec…])` | Skip scan in an explicit order. | NO_INDEX_SS | 9.0 | yes | Last resort |
| NO_INDEX_SS | `no_index_ss([@qb] tablespec [indexspec…])` | Exclude a skip scan of the listed indexes. | INDEX_SS | 10.1 | yes | Last resort |
| CLUSTER | `cluster([@qb] tablespec)` | Cluster scan. Only for tables in an indexed cluster. | — | 8.0 | yes | Niche |
| HASH | `hash([@qb] tablespec)` | Hash scan. Only for tables in a hash cluster. This is **not** a hash join — that's `USE_HASH`. | — | 8.1 | yes | Niche |
| NATIVE_FULL_OUTER_JOIN | `native_full_outer_join` | Use the hash-based native full outer join. | NO_NATIVE_FULL_OUTER_JOIN | 10.2 | yes | Last resort |
| NO_NATIVE_FULL_OUTER_JOIN | `no_native_full_outer_join` | Run the full outer join as a left outer join `union all` an anti-join. | NATIVE_FULL_OUTER_JOIN | 10.2 | yes | Last resort |
| CLUSTERING / NO_CLUSTERING | `clustering` | Turn attribute clustering on or off for a direct-path `insert`/`merge` into an attribute-clustered table. | each other | 12.1 | no | Niche |
| NO_ZONEMAP | `no_zonemap([@qb] tablespec {scan\|join\|partition})` | Disable zone-map pruning. | — | 12.1 | no | Niche |
| INMEMORY / NO_INMEMORY | `inmemory([@qb] tablespec)` | Enable or disable an In-Memory scan. It does not force a full scan — add `FULL` for that. | each other | 12.1.0.2 | no | Niche |
| INMEMORY_PRUNING / NO_INMEMORY_PRUNING | `inmemory_pruning([@qb] tablespec)` | Enable or disable In-Memory storage-index pruning. | each other | 12.1.0.2 | no | Niche |

---

## Join order

| Hint | Syntax | What it does | Inverse | Since | CBO | Team use |
|---|---|---|---|---|---|---|
| LEADING | `leading([@qb] tablespec [tablespec…])` | Use these tables, in this order, as the prefix of the join order. The first one drives. It is ignored if the join graph makes that order impossible, and two conflicting `LEADING` hints cancel each other. | — | 8.1.6 | yes | Last resort — the most useful plan-shaping hint, but always pair it with the join methods (see [Join operations](#join-operations)) |
| ORDERED | `ordered` | Join in `from`-clause order. It takes no arguments, overrides every `LEADING` hint, and breaks silently when someone reorders the `from` clause or when a transformation reshuffles tables. | — | 8.1 | yes | Avoid — use `LEADING` |

---

## Join operations

The official definition: *"USE_NL … join each specified table to another
row source … using the specified table as the **inner** table."*
`use_nl(a b)` is **not** "nested-loop a to b". It is shorthand for
`use_nl(a) use_nl(b)`, and each half only applies when that table ends up
as the inner (probe) table. That's why these hints travel with `LEADING`.

| Hint | Syntax | What it does | Inverse | Since | CBO | Team use |
|---|---|---|---|---|---|---|
| USE_NL | `use_nl([@qb] tablespec…)` | Nested-loops join **into** the named (inner) table. | NO_USE_NL | 8.1 | yes | Last resort, with `LEADING` |
| NO_USE_NL | `no_use_nl([@qb] tablespec…)` | Exclude nested loops into the named table. It is ignored where only nested loops are possible. | USE_NL | 10.1 | yes | Last resort |
| USE_NL_WITH_INDEX | `use_nl_with_index([@qb] tablespec [indexspec…])` | Nested loops into the named table **using an index** on at least one join predicate. | NO_USE_NL | 10.1 | yes | Last resort |
| USE_HASH | `use_hash([@qb] tablespec…)` | Hash join into the named table. Requires an **equality** join predicate — impossible on `between`/range joins. | NO_USE_HASH | 8.1 | yes | Last resort, with `LEADING` |
| NO_USE_HASH | `no_use_hash([@qb] tablespec…)` | Exclude hash joins into the named table. | USE_HASH | 10.1 | yes | Last resort |
| USE_MERGE | `use_merge([@qb] tablespec…)` | Sort-merge join into the named table. | NO_USE_MERGE | 8.1 | yes | Last resort |
| NO_USE_MERGE | `no_use_merge([@qb] tablespec…)` | Exclude sort-merge joins. | USE_MERGE | 10.1 | yes | Last resort |
| USE_BAND / NO_USE_BAND | `use_band([@qb] tablespec…)` | Use or exclude a band join, for range joins like `a.x between b.y - 100 and b.y + 100`. | each other | 12.2 docs (not in `V$SQL_HINT`) | — | Last resort |
| USE_CUBE / NO_USE_CUBE | `use_cube([@qb] tablespec…)` | Use or exclude a cube join when the right side is a cube. | each other | 12.1 | yes | Niche |

**Complete-set example.** Pin the order and every join method:

```sql
select /*+ leading(o c ol) use_nl(c) use_nl(ol) index(ol (order_id)) */
       o.order_id                                as order_id
     , c.customer_name                           as customer_name
     , ol.product_id                             as product_id
  from prefix_orders                  o
  join prefix_customers               c on c.customer_id = o.customer_id
  join prefix_order_lines            ol on ol.order_id   = o.order_id
 where o.order_date >= trunc(sysdate) - 1;
```

---

## Query transformations

A transformation rewrites the query before costing — view merging, subquery
unnesting, predicate pushing, OR-expansion. Hints written against the
*original* shape can become unresolvable after a transformation. That is
the #1 cause of "my `LEADING` was ignored".

| Hint | Syntax | What it does | Inverse | Since | CBO | Team use |
|---|---|---|---|---|---|---|
| MERGE | `merge` (inside the view) / `merge([@qb] view)` (outside it) | Merge the view or inline view into the outer query block. `group by`/`distinct` views need complex view merging. | NO_MERGE | 8.1 | yes | Last resort |
| NO_MERGE | `no_merge` (inside) / `no_merge([@qb] view)` (outside) | Keep the view as its own query block and optimize it separately. It preserves `LEADING`/`ORDERED` intent that merging would otherwise destroy. | MERGE | 8.0 | yes | Last resort |
| PUSH_PRED | `push_pred([@qb] view)` | Push the join predicate into a non-merged view, so it can use an index per outer row. | NO_PUSH_PRED | 8.1 | yes | Last resort |
| NO_PUSH_PRED | `no_push_pred([@qb] view)` | Don't push the join predicate into the view. | PUSH_PRED | 8.1 | yes | Last resort |
| PUSH_SUBQ | `push_subq[(@qb)]` | Evaluate a non-merged subquery as early as possible. No effect on remote tables or merge joins. | NO_PUSH_SUBQ | 8.1 | yes | Last resort |
| NO_PUSH_SUBQ | `no_push_subq[(@qb)]` | Evaluate a non-merged subquery last. Good when it's expensive and filters little. | PUSH_SUBQ | 9.2 | yes | Last resort |
| UNNEST | `unnest[(@qb)]` | Unnest the subquery into a join. It checks validity only, skipping the heuristic and cost tests. | NO_UNNEST | 8.1.6 | yes | Last resort |
| NO_UNNEST | `no_unnest[(@qb)]` | Keep the subquery as a filter subquery. | UNNEST | 8.1.6 | yes | Last resort |
| USE_CONCAT | `use_concat[(@qb)]` | Force OR-expansion into `union all` branches, overriding cost. | NO_EXPAND | 8.1 | yes | Last resort |
| NO_EXPAND | `no_expand[(@qb)]` | Prevent OR-expansion of `or`/`in` predicates. | USE_CONCAT | 8.1 | yes | Last resort |
| REWRITE | `rewrite[([@qb] mview…)]` | Force materialized-view query rewrite regardless of cost. | NO_REWRITE | 8.1.5 | yes | Niche |
| NO_REWRITE | `no_rewrite[(@qb)]` | Disable query rewrite for the block. | REWRITE | 8.1.5 | yes | Niche |
| STAR_TRANSFORMATION | `star_transformation[(@qb)]` | Use the best star-transformed plan, if the transformation happens at all. | NO_STAR_TRANSFORMATION | 8.1 | yes | Niche |
| NO_STAR_TRANSFORMATION | `no_star_transformation[(@qb)]` | Don't star-transform. | STAR_TRANSFORMATION | 10.1 | yes | Niche |
| FACT / NO_FACT | `fact([@qb] tablespec)` | Treat, or don't treat, the table as the fact table in a star transformation. | each other | 8.1 | yes | Niche |
| NO_QUERY_TRANSFORMATION | `no_query_transformation` | Skip **all** transformations. Use it with `explain plan … +alias` to see the *pre-transformation* query block names. | — | 10.1 | yes | Diagnostic |

---

## Parallel execution

Since 11gR2, `PARALLEL` / `NO_PARALLEL` are **statement-level** hints. The
object-level forms (`parallel(t 8)`, `PARALLEL_INDEX`) exist for backward
compatibility.

| Hint | Syntax | What it does | Inverse | Since | CBO | Team use |
|---|---|---|---|---|---|---|
| PARALLEL (statement) | `parallel` \| `parallel(default\|auto\|manual\|n)` | Run the whole statement in parallel: DOP *n*, computed (`default`/`auto`), or the objects' own DOP (`manual`). A plan with sorts or grouping can use twice *n* servers. It is ignored if any parallel restriction is violated. | NO_PARALLEL | 8.1 (listed in `V$SQL_HINT` as `SHARED`) | no | Allowed in batch/ETL code; Avoid in interactive APEX page SQL |
| PARALLEL (object) | `parallel([@qb] tablespec [n\|default])` | Legacy per-table DOP. | NO_PARALLEL | 8.1 | no | Avoid — use the statement form |
| NO_PARALLEL | `no_parallel[([@qb] tablespec)]` | Run serially, overriding `PARALLEL_DEGREE_POLICY` and table DOP. On a table it does not stop a parallel *index* scan — that needs `NO_PARALLEL_INDEX`. | PARALLEL | 10.1 | no | Allowed |
| PARALLEL_INDEX / NO_PARALLEL_INDEX | `parallel_index([@qb] tablespec [indexspec…] [n])` | Parallelize, or don't, index scans on **partitioned** indexes. | each other | 8.1 | no | Niche |
| ENABLE_PARALLEL_DML | `enable_parallel_dml` | Enable parallel DML for one statement instead of `alter session enable parallel dml`. | DISABLE_PARALLEL_DML | 11.2.0.4 | no | Allowed in batch code |
| DISABLE_PARALLEL_DML | `disable_parallel_dml` | Disable parallel DML for one statement in a session that enabled it. | ENABLE_PARALLEL_DML | 11.2.0.4 | no | Allowed |
| PQ_DISTRIBUTE | `pq_distribute([@qb] tablespec outer inner)` / `pq_distribute(tablespec none\|partition\|random\|random_local)` | Choose how rows move between producer and consumer servers, for joins (`hash,hash`, `broadcast,none`, `none,broadcast`, `partition,none`, `none,partition`, `none,none`) or for loads. | — | 8.1.5 | yes | Last resort |
| PQ_FILTER | `pq_filter(serial\|none\|hash\|random)` | Choose how parallel rows are processed through a correlated-subquery filter. | — | 12.1 | no | Last resort |
| PQ_SKEW / NO_PQ_SKEW | `pq_skew([@qb] tablespec)` | Declare that the probe table's join keys are, or aren't, skewed. | each other | 12.1 | yes | Last resort |
| PQ_CONCURRENT_UNION / NO_PQ_CONCURRENT_UNION | `pq_concurrent_union[(@qb)]` | Run `union [all]` branches concurrently, or not. | each other | 12.1 | no | Niche |
| PX_JOIN_FILTER / NO_PX_JOIN_FILTER | `px_join_filter(tablespec)` | Force or prevent parallel join bloom filtering. | each other | 10.2 | yes | Last resort |
| STATEMENT_QUEUING / NO_STATEMENT_QUEUING | `no_statement_queuing` | Opt in to, or bypass, parallel statement queuing. Bypassing can exceed `PARALLEL_SERVERS_TARGET`. | each other | 11.2 | no | Avoid (a DBA decision, not code) |
| NOPARALLEL / NOPARALLEL_INDEX | — | Deprecated spellings. | — | 8.1 | no | Avoid — use `NO_PARALLEL` / `NO_PARALLEL_INDEX` |

> **Note:** on Autonomous Database, APEX sessions run on the **LOW**
> service, which has no parallelism. A `PARALLEL` hint in page SQL won't
> parallelize there — see [`apex.md`](apex.md#apex-on-autonomous-database)
> for the APEX-specific way around that. Oracle Free (`parallel_max_servers
> = 1`) never runs in parallel, so `parallel(n)` shows as `U` there.

---

## Online application upgrade — semantic hints

These three are unlike every other hint. They **change the result or error
behaviour** of the statement, and misusing them raises errors instead of
being silently ignored. A *syntax* error still makes them vanish silently,
though, and the original `ORA-00001` comes back. All three disable `APPEND`
mode and parallel DML.

| Hint | Syntax | What it does | Since | CBO | Team use |
|---|---|---|---|---|---|
| IGNORE_ROW_ON_DUPKEY_INDEX | `ignore_row_on_dupkey_index(t, t_uk)` or `(t (col1, col2))` | Single-table `insert` only (not `merge`/`update`/multi-table, and not through views). A duplicate on that unique index rolls back just that row and continues. Specify exactly one index: none gives `ORA-38912`, a non-unique or missing index gives `ORA-38913`, more than one gives `ORA-38915`. | 11.1.0.7 | no | Allowed with care — each duplicate costs a row-level rollback. For upserts we use `merge` (`sql-format.md` §9) |
| CHANGE_DUPKEY_ERROR_INDEX | `change_dupkey_error_index(t, t_uk)` | For `insert`/`update`: a violation of *this* unique key raises `ORA-38911` instead of `ORA-00001`, so the caller can tell which key failed. It can't be combined with `IGNORE_ROW_ON_DUPKEY_INDEX`. | 11.1.0.7 | no | Niche |
| RETRY_ON_ROW_CHANGE | `retry_on_row_change` | `update`/`delete` only: retry the operation if a target row's `ORA_ROWSCN` changed between row selection and block modification. Built for edition-based redefinition. | 11.1.0.7 | no | Niche |

---

## Other documented hints

| Hint | Syntax | What it does | Inverse | Since | CBO | Team use |
|---|---|---|---|---|---|---|
| APPEND | `insert /*+ append */ into t select …` | Direct-path insert above the high-water mark, bypassing the buffer cache. Subquery form only — ignored with `values`. See the restrictions below the table. | NOAPPEND | 8.1 | no | Allowed in bulk/batch loads only |
| APPEND_VALUES | `insert /*+ append_values */ into t values (…)` | Direct path for the `values` form. Built for `forall` array inserts from PL/SQL and OCI array binds. It is ignored with a subquery. | NOAPPEND | 11.2 | no | Allowed in bulk `forall` loads only |
| NOAPPEND | `noappend` | Conventional insert even when the insert runs in parallel. | APPEND | 8.1 | no | Allowed |
| CACHE / NOCACHE | `full(t) cache(t)` | Place full-scanned blocks at the most- or least-recently-used end of the buffer cache LRU. | each other | 8.1 | no | Avoid (a DBA storage decision) |
| CONTAINERS | `containers(default_pdb_hint='no_parallel')` | Pass a hint to the recursive per-PDB SQL of a `containers()` query. | — | 12.2 | no | Niche |
| CURSOR_SHARING_EXACT | `cursor_sharing_exact` | Don't replace literals with binds even if `CURSOR_SHARING=FORCE`. | — | 9.0 | no | Allowed (rare) |
| DRIVING_SITE | `driving_site([@qb] tablespec)` | Execute a distributed query at the site of the named table — ship the small side to the big side over the db link. | — | 8.1 | no | Allowed (db-link queries) |
| DYNAMIC_SAMPLING | `dynamic_sampling([@qb] [tablespec] 0-10)` | Sample at parse time to estimate selectivity. It **requires** a level — bare `dynamic_sampling` is a syntax error. With existing stats and no single-table predicate it is ignored. | — | 9.2 | yes | Last resort — fix the statistics instead |
| FRESH_MV | `fresh_mv` | Use on-query computation of a real-time materialized view even if it's stale. | — | 12.2 | no | Niche |
| GATHER_OPTIMIZER_STATISTICS | `gather_optimizer_statistics` | Gather online statistics during CTAS or a direct-path insert into an empty table. | NO_GATHER_OPTIMIZER_STATISTICS | 12.1 | no | Allowed in bulk loads |
| NO_GATHER_OPTIMIZER_STATISTICS | `no_gather_optimizer_statistics` | Skip online statistics on bulk loads, and real-time statistics on conventional loads. | GATHER_OPTIMIZER_STATISTICS | 12.1 | no | Allowed in bulk loads |
| GROUPING | `prediction(/*+ grouping */ my_model using *)` | Score a partitioned machine-learning model partition by partition. | — | not in `V$SQL_HINT` | — | Niche |
| MODEL_MIN_ANALYSIS | `model_min_analysis` | Skip some compile-time analysis of `model` clause rules. | — | 10.1 | no | Niche |
| MONITOR / NO_MONITOR | `monitor` | Force, or suppress, Real-Time SQL Monitoring. Needs `CONTROL_MANAGEMENT_PACK_ACCESS = DIAGNOSTIC+TUNING`, so it requires a **Tuning Pack** licence. | each other | 11.1 | no | Diagnostic |
| QB_NAME | `qb_name(my_block)` | Name the query block so other hints can target `@my_block`. It has no plan effect of its own. Two blocks with the same name make every hint on them ignored. | — | 10.1 | no | Allowed — encouraged whenever you hint across blocks |
| RESULT_CACHE | `result_cache` \| `result_cache(shelflife=120)` \| `result_cache(temp=true shelflife=120)` | Cache the result of the query, `with`-clause block, or inline view in the shared-pool result cache. It is invalidated by any committed DML on a dependency. `SHELFLIFE` (seconds before forced invalidation) is in the current 19c docs. `TEMP` (allow spilling to the temporary tablespace) is 21c+, and on 19c only available on ADB. On 26ai, `RESULT_CACHE_INTEGRITY=ENFORCED` refuses to cache results that use non-deterministic PL/SQL. | NO_RESULT_CACHE | 11.1 | no | Allowed for small, read-mostly lookups — never for per-user or volatile data |
| NO_RESULT_CACHE | `no_result_cache` | Don't cache even if `RESULT_CACHE_MODE=FORCE`. | RESULT_CACHE | 11.1 | no | Allowed |
| NO_XML_QUERY_REWRITE / NO_XMLINDEX_REWRITE | `no_xml_query_rewrite` | Disable XPath rewrite or XMLIndex use. | — | 9.2 / 11.1 | no | Niche |
| COMPRESS_IMMEDIATE | `compress_immediate` | 26ai docs (in `V$SQL_HINT` since 23.1). Compress a direct load immediately instead of waiting for Automatic Storage Compression. | NO_COMPRESS_IMMEDIATE | 23.1 | no | Niche |

**Direct-path (`APPEND` / `APPEND_VALUES`) restrictions.** `APPEND` is not
in the hint report's scope. Verify it in the **plan** instead: `LOAD AS
SELECT` means direct path, `LOAD TABLE CONVENTIONAL` means it fell back —
and on 26ai the *Note* section says why (see
[`sql-and-plsql.md`](sql-and-plsql.md#direct-path-loads-append-and-append_values)).
Break any of these and Oracle *silently* runs a conventional serial insert
([INSERT, 19c](https://docs.oracle.com/en/database/oracle/oracle-database/19/sqlrf/INSERT.html)):

- The target table has **any triggers or referential-integrity
  constraints**. Every table built from our
  [`table_template.sql`](../../templates/table_template.sql) has a compound
  audit trigger and usually FKs, so `APPEND` on a standard application table
  is a no-op. Stage into a trigger-less, FK-less table instead.

- The table is clustered, has object-type columns, is replicated, or the
  transaction is distributed (db link). IOTs have extra limits.

- **Touch-once rule (19c):** after a direct-path insert, the same
  transaction cannot query or modify that table — you get `ORA-12838` until
  you `commit`. **23ai / 26ai** lift this for heap tables in ASSM
  tablespaces ("Unrestricted Direct Loads"), and the 26ai `INSERT` page no
  longer carries the `ORA-12838` paragraph.

- `APPEND` doesn't reduce redo in an `ARCHIVELOG` database unless the table
  or tablespace is also `NOLOGGING` — which limits recovery. Don't use
  `NOLOGGING` for anything you care about.

---

## Vector search hints (23ai / 26ai)

Documented in the *AI Vector Search User's Guide*, not in the SQL Language
Reference hint list.

| Hint | Syntax | What it does | Since | CBO | Team use |
|---|---|---|---|---|---|
| VECTOR_INDEX_SCAN / NO_VECTOR_INDEX_SCAN | `vector_index_scan([@qb] tablespec [indexspec])` | Access-path hint for a simple single-table, predicate-less top-K query on an **HNSW** index. | 23.1 | yes | Niche |
| VECTOR_INDEX_TRANSFORM / NO_VECTOR_INDEX_TRANSFORM | `vector_index_transform([@qb] tablespec [indexspec [filtertype]])` | Transformation hint for every other case. `filtertype` is `pre_filter_with_join_back` (HNSW), `pre_filter_without_join_back` (HNSW and IVF), `in_filter_with_join_back` / `in_filter_without_join_back` (HNSW), or `post_filter_without_join_back` (HNSW and IVF). Specifying `filtertype` requires `indexspec`. | 23.1 | yes | Niche |
| IVF_ITERATION / NO_IVF_ITERATION | `ivf_iteration` | Use, or don't use, terminable-iteration IVF search with `fetch first n rows only with target accuracy …`. | 23.1 | yes | Niche |

> **Note:** to *guarantee* an exact (non-index) vector search, Oracle's
> guide says to use `fetch exact first n rows only` rather than a `no_*`
> hint.

---

## Look like hints, aren't optimizer hints

| Name | What it really is |
|---|---|
| `WITH_PLSQL` | Required when a statement that isn't the top-level `select` contains a `with function …` declaration. Always required for `insert`/`update`/`delete`/`merge`. The SQL Reference says: *"It is not an optimizer hint."* **Verified on 26ai:** `ORA-32034` on every API when the function is actually used, but *no* error when the outer query prunes the function column (`count(*)`) — so test with the real select list. APEX lists it in the Optimizer Hint attribute because APEX wraps your query. See [`sql-and-plsql.md`](sql-and-plsql.md#with_plsql) and [`apex.md`](apex.md). |
| `APEX$USE_…`, `apex-adb-high`, `apex-adb-medium` | APEX pseudo hints. APEX reads them and changes the SQL it generates, but they still reach the database inside the `--+` comment, where the hint report shows them as `E`. That is harmless: a bare word doesn't stop the hints after it (verified on 26ai). See [`apex.md`](apex.md#apex-pseudo-hints). |
| `NOCOPY`, `PRAGMA UDF`, `PRAGMA INLINE`, `DETERMINISTIC`, `RESULT_CACHE` (function clause) | PL/SQL compiler directives and declarations, not SQL hints. The optimizer's hint report never mentions them. |
| `CELL_FLASH_CACHE` | An Exadata **storage clause** (`alter table t storage (cell_flash_cache keep)`). It is not in `V$SQL_HINT` (verified on 26ai), so `/*+ cell_flash_cache(keep) */` is a syntax error (`E`) — and because it has parentheses, it also discards every hint written after it. The packaged `db:db` skill's `exadata-features.md` lists it as a hint — it isn't. |
| `NOLOCK` | SQL Server syntax. Oracle readers never block writers, so there is nothing to hint. |

---

## Undocumented hints you will meet

`V$SQL_HINT` lists **406** names in 23.1 and **425** in 26ai (23.26.1). Only about a hundred are in the
SQL Language Reference (101 in 19c, 103 in 26ai), so the rest are
unsupported. Oracle generates many of
them itself in **Outline Data**, SQL Plan Baselines and SQL Profiles, which
is why you see them. Copying a full outline into code is legitimate
debugging practice, but a *hand-written* undocumented hint in committed code
is a support risk.

| Hint | Where you'll see it | What it does | Since | Team use |
|---|---|---|---|---|
| MATERIALIZE / INLINE | Blogs, legacy code, outlines (outline-capable since 18.1) | Force a `with`-clause block to be materialized as a temp table, or merged inline. | 9.0 | **`materialize`: Last resort, with evidence.** A CTE referenced twice *by name* is already materialized automatically (verified on 26ai). The hint earns its place only when `V$SQL_PLAN_MONITOR.STARTS` shows a CTE re-executed because a transformation duplicated a single reference — e.g. `UNPIVOT` rewritten to one `UNION ALL` branch per column. That was the biggest win in the [`oracle-performance-investigation`](../oracle-performance-investigation/SKILL.md) case (§3), and pure noise where `STARTS` was already 1 (§12). `inline`: Avoid. |
| CARDINALITY | Blogs, legacy code | `cardinality(t 100)` fixes a row estimate for a table, query block or join. | 9.0 | Avoid — fix the stats, or use a SQL Profile |
| OPT_ESTIMATE | SQL Profiles | Scale or fix optimizer estimates. This is what SQL Tuning Advisor profiles contain. | 10.1 | Avoid by hand |
| GATHER_PLAN_STATISTICS | Every tuning session | Collect row-source statistics (A-Rows, A-Time, Buffers) for `dbms_xplan … 'ALLSTATS LAST'`. Referenced in the `DBMS_XPLAN` docs. | 10.1 | Diagnostic |
| IGNORE_OPTIM_EMBEDDED_HINTS | Outline Data, SQL Patches | Disable every CBO-class hint embedded in the statement. | 10.1 | Allowed **inside a SQL Patch** only |
| OUTLINE_LEAF, DB_VERSION, BEGIN_OUTLINE_DATA / END_OUTLINE_DATA | Outline Data | Outline bookkeeping. | 10.x | Leave them to Oracle |
| INDEX_RS_ASC / INDEX_RS_DESC | Outline Data | Index **range** scan specifically. The documented `INDEX` hint leaves the scan type open. | 11.1 | Avoid by hand |
| SWAP_JOIN_INPUTS / NO_SWAP_JOIN_INPUTS | Outline Data | Choose the build table of a hash join. Jonathan Lewis's "hint completely" examples use it. | 8.1 | Avoid by hand |
| NO_ADAPTIVE_PLAN | Outline Data, blogs | Disable adaptive join-method switching for the statement. | 12.1.0.2 | Last resort |
| OR_EXPAND / NO_OR_EXPAND | Outline Data (12.2+ cost-based OR-expansion) | The modern replacement for `USE_CONCAT`. | 12.2 | Avoid by hand |
| NLJ_BATCHING / NO_NLJ_BATCHING, BATCH_TABLE_ACCESS_BY_ROWID | Outline Data | Nested-loop execution details. | 11.1 / 12.1 | Leave them to Oracle |
| ELIMINATE_JOIN, PLACE_GROUP_BY, USE_HASH_AGGREGATION, BIND_AWARE … | Outline Data, blogs | Various transformation and cursor-sharing switches. | various | Avoid |

---

## Deprecated or removed

| Hint | Status | Use instead |
|---|---|---|
| `RULE` | The rule-based optimizer is unsupported and frozen since 7.3. It must be the *only* hint in the statement. No partitions, IOTs, parallel or flashback. | Nothing — delete it and fix the statement properly |
| `CHOOSE` | Removed along with the `CHOOSE` optimizer mode | — |
| `FIRST_ROWS` (no *n*) | Kept for backward compatibility only | `first_rows(n)` |
| `ORDERED_PREDICATES`, `AND_EQUAL`, `STAR` | Legacy | — |
| `HASH_AJ`, `MERGE_AJ`, `NL_AJ`, `HASH_SJ`, `MERGE_SJ`, `NL_SJ` | Legacy anti/semi-join hints | Let the optimizer choose, or `UNNEST` / `NO_UNNEST` |
| `NOPARALLEL`, `NOPARALLEL_INDEX`, `NOREWRITE` | Deprecated spellings | `NO_PARALLEL`, `NO_PARALLEL_INDEX`, `NO_REWRITE` |
