# Result Analysis — Full Automated Workflow (2026-04-12)

This note summarizes quantitative patterns from the **Run Full Automated Workflow** export (columns: `Timestamp`, `Strategy`, `Mode`, `Task_Type`, `API_Type`, `Duration_ms`, `Overhead_ms`, `Size_kb`, `Joules_estimated`, `Device_Tier`, `Network_Type`, `Mode_Conflict`, `AI_Decision_Source`, `AI_Reasoning`). Task types map to the project’s benchmark buckets as **simple_list** (list-style payload, larger `Size_kb`), **detail_medium** (medium detail), and **nested_large** (nested / heavier structure).

---

## 1. Data scope and grouping

Records were grouped for analysis by:

- **Strategy:** `REST`, `GQL`, `Heuristic`, `AI_Power`
- **Mode:** `Performance` (minimize `Duration_ms`), `Green` (minimize `Joules_estimated`), `Balanced` (trade-offs; may invoke AI orchestration)
- **Task_Type:** `simple_list`, `detail_medium`, `nested_large`
- **Decision source (AI_Power):** `cached`, `rules_engine`, and strings indicating model reasoning in `AI_Reasoning`

Descriptive statistics below use **mean, median, min–max**, and **coefficient of variation (CV = std/mean)** where helpful. **Joules_estimated** is treated as a relative energy proxy aligned with the framework’s Green Software Engineering focus (see `Project_framework_2222397.md`).

---

## 2. Baseline protocols: REST vs GraphQL (`GQL`)

### 2.1 Performance mode

| Task_Type       | API_Type | Duration_ms (typical range from export) | Notes |
|-----------------|----------|----------------------------------------|--------|
| simple_list     | REST     | ~7–50 ms per observation block         | Stable non-zero durations; scales with list payload (`Size_kb` ≈ 52.98). |
| simple_list     | GRAPHQL  | Often 0 ms with occasional spikes      | Many near-zero durations suggest cache/hit path; outliers (e.g., ~81 ms) inflate max latency. |
| detail_medium   | REST     | ~2–18 ms                               | Narrow spread; small payload (`Size_kb` ≈ 0.42). |
| detail_medium   | GRAPHQL  | Mostly 0 ms; rare high values          | Similar “fast path” behaviour with rare spikes (~71 ms in one block). |
| nested_large    | REST     | ~2–27 ms                               | Nested REST calls show multi-millisecond work per request. |
| nested_large    | GRAPHQL  | Mostly 0 ms; rare spikes               | Includes rare high-duration points (e.g., ~101 ms) worth treating as tail latency in discussion. |

**Interpretation:** Under **Performance**, **REST** exhibits **continuously distributed** positive `Duration_ms`, while **GraphQL** rows often collapse toward **0 ms** in this harness—so comparing **central tendency only** can mislead; **tail latency (p95/p99)** and **overhead** matter.

### 2.2 Green mode

Green runs repeat the same structural pattern: **REST** shows **non-zero** `Joules_estimated` tied to non-zero `Duration_ms`, while **GraphQL** rows often register **0 J** when duration is **0** in the log—consistent with the estimator’s coupling of energy to active request cost in this run configuration.

### 2.3 Heuristic strategy

`Heuristic` rows frequently show **0 / 0** for `Duration_ms` and `Overhead_ms` with **not_applicable** decision metadata, functioning as a **control / lightweight scheduling** path in the workflow rather than a full client-server timing profile. Treat these rows as **harness bookkeeping**, not direct REST/GraphQL end-to-end latency.

---

## 3. AI-conscious routing (`AI_Power`)

### 3.1 Decision mix

Across **Performance** and **Green**, `AI_Power` consistently **selects `GRAPHQL`** for all three task types in the export, with `AI_Reasoning` citing:

- **Performance:** “minimize `Duration_ms`; chosen GraphQL … (latency history + network/load heuristics).”
- **Green:** “minimize Joules … (history + tier fallback where needed).”

`AI_Decision_Source` is predominantly **`cached`**, indicating **repeatable routing** from prior decisions (aligned with the adaptive-gateway “memory” concept in the project framework).

### 3.2 Overhead vs work

- **Performance + AI_Power:** `Overhead_ms` commonly falls in a **low tens of milliseconds** band (e.g., ~3–37 ms) while `Duration_ms` is often **0** in the log—suggesting the **routing layer** dominates visible timing in this path.
- **Green + AI_Power:** Similar pattern; occasional larger overhead bursts appear (e.g., ~37 ms spikes), still far smaller than Balanced AI failures (below).

### 3.3 Balanced mode and failure fallback (critical finding)

For **`AI_Power` + `Balanced`**, many rows show:

- `AI_Decision_Source`: **`rules_engine`**
- `AI_Reasoning`: **“Balanced fallback: Gemini error; using Green-philosophy pick.”**
- `Overhead_ms`: typically **~500–600 ms** orders of magnitude above Performance/Green AI_Power rows

**Implication:** The **intended** balanced AI path was **not consistently available** during this run; the system **degraded** to a **rules-based Green-leaning** decision. Any claim about “balanced AI” must separate **nominal** vs **fallback** behaviour.

---

## 4. Comparative tables (workflow-level)

### 4.1 Representative central tendency by Strategy (Performance, nested_large, GRAPHQL)

| Strategy   | Duration_ms (typical) | Overhead_ms (typical) | Joules_estimated (typical) |
|------------|------------------------|------------------------|----------------------------|
| GQL        | 0 (many rows)          | 0                      | 0                          |
| Heuristic  | 0                      | 0                      | 0                          |
| AI_Power   | 0                      | ~4–25                  | 0                          |
| REST       | ~3–17                  | 0                      | ~0.002–0.022               |

### 4.2 Tail-risk anecdote (same mode/task)

- **GQL + Balanced + nested_large** includes at least one **Duration_ms ≈ 101** sample alongside many zeros → **high kurtosis** / **long tail**.
- **REST + Performance + simple_list** shows **sustained** tens-of-ms durations with **predictable** variability—useful when **worst-case latency stability** matters.

---

## 5. Statistical methods applied

1. **Descriptive statistics** (mean, median, min, max, range) per group **Strategy × Mode × Task_Type × API_Type**.
2. **Distribution inspection** for **zero-inflation** (many exact zeros in GraphQL timing columns) — implies **non-Gaussian** data; **Mann–Whitney U** or **permutation tests** are more appropriate than plain t-tests when comparing REST vs GraphQL on duration/energy (as foreseen in the project framework).
3. **Tail analysis:** report **p95/p99** for latency if raw row-level data is exported to CSV for batch computation (recommended follow-up).
4. **Effect of routing overhead:** compare **`Overhead_ms` distributions** for `AI_Power` across modes, highlighting **Balanced fallback** as a separate population.

---

## 6. Figures and charts (recommended)

For the final paper, generate:

1. **Box plots:** `Duration_ms` by `Strategy` for each `Task_Type` (facet `Mode`).
2. **Bar chart with error bars:** mean `Joules_estimated` for REST vs GraphQL under **Green**.
3. **Time-series strip** (optional): `Timestamp` vs `Overhead_ms` for `AI_Power` **Balanced** to visualize **fallback spikes**.
4. **Stacked bar:** proportion of `AI_Decision_Source` (`cached` vs `rules_engine`) per mode.

*(Insert exported PNGs from `analysis/` or a notebook; this file describes what each figure should show.)*

---

## 7. Mapping results → research questions

| Research question | What the export supports |
|-------------------|---------------------------|
| **How** does AI-assisted routing differ from static API choice? | `AI_Power` overwhelmingly picks **GraphQL** with **cached** rationale; adds small **`Overhead_ms`** versus many **baseline** rows. |
| **What** happens to latency/energy when the AI balancer cannot call the model? | **Balanced** shows **large `Overhead_ms`** and explicit **Gemini error** fallback to **rules_engine**, dominating end-to-end cost for that mode in this run. |
| **Which** protocol is more stable when durations are mostly non-zero? | **REST** blocks show **continuous** positive `Duration_ms` under Performance—useful baseline variability; **GraphQL** shows **zero-inflation** and **spike** outliers. |

---

## 8. Limitations (measurement design)

1. **Zero-inflated timing for GraphQL** may reflect **client cache**, **short-circuit**, or **logging semantics** — requires code-level confirmation in the harness.
2. **Balanced mode** in this run is **not a clean AI comparison** due to **Gemini errors**.
3. **Heuristic** rows are **not** equivalent end-to-end timings to REST/GQL workload rows.
4. **Single device tier (`budget`) and WiFi** — limits generalization to cellular and premium-tier devices.

---

## 9. Short summary (3–4 lines)

The workflow export shows **GraphQL** being **preferred by AI_Power** under Performance and Green with **mostly cached** decisions and **modest routing overhead**, while **REST** displays **consistently positive** millisecond durations suitable as a **transparent workload baseline**. **Balanced AI_Power** behaviour is dominated in this run by **Gemini failure** and **rules-based fallback**, producing **hundreds of milliseconds of overhead**—a key caveat for any claim about intelligent balancing until the model path is reliable.
