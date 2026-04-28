# Conscious API Routing System — Technical Reference
## Green Software Engineering Research — CSE451

> **Project:** Adaptive REST/GraphQL API Router for Mobile Applications  
> **Platform:** Flutter (Android/iOS)  
> **AI Backend:** Google Gemini (via `google_generative_ai` Dart SDK)  
> **Primary Source Files:** `conscious_router.dart`, `device_profiler.dart`, `energy_estimator.dart`, `ai_policy_store.dart`, `service_locator.dart`, `api_history_provider.dart`

---

## Table of Contents

1. [System Overview](#1-system-overview)
2. [Core Abstractions](#2-core-abstractions)
3. [Device Profiling Subsystem](#3-device-profiling-subsystem)
4. [Energy Estimation Model](#4-energy-estimation-model)
5. [Routing Strategies Overview](#5-routing-strategies-overview)
6. [Green Mode — Algorithm Deep Dive](#6-green-mode--algorithm-deep-dive)
7. [Performance Mode — Algorithm Deep Dive](#7-performance-mode--algorithm-deep-dive)
8. [Balanced (AI) Mode — Algorithm Deep Dive](#8-balanced-ai-mode--algorithm-deep-dive)
9. [AI Policy Cache (AiPolicyStore)](#9-ai-policy-cache-aipolicystore)
10. [Heuristic Learning Phase](#10-heuristic-learning-phase)
11. [AdaptiveApiService — The Dispatcher](#11-adaptiveapiservice--the-dispatcher)
12. [Data Collection & Provenance](#12-data-collection--provenance)
13. [Mode Conflict Signal](#13-mode-conflict-signal)
14. [Full Routing Execution Flow (end-to-end)](#14-full-routing-execution-flow-end-to-end)
15. [Research Fairness Note](#15-research-fairness-note)

---

## 1. System Overview

The project implements a **Conscious Router** that sits between the Flutter UI layer and two wire protocols — **REST** (standard HTTP/JSON) and **GraphQL** — and dynamically selects which protocol to use for every API call. The selection is driven by one of three operating modes:

| Mode | Decision Maker | Optimisation Objective |
|---|---|---|
| **Green** | Rules Engine | Minimize energy (Joules) |
| **Performance** | Rules Engine | Minimize latency (ms) |
| **Balanced** | Google Gemini LLM | Trade-off: energy vs. latency |

The active mode is stored in the global string `currentOperatingMode` (from `app_state.dart`). The active routing strategy (which selects between static REST, static GraphQL, heuristic learning, comparison, or AI-powered routing) is stored in `currentRoutingStrategy`.

---

## 2. Core Abstractions

### 2.1 `ApiDecision` enum
```dart
enum ApiDecision { rest, graphql }
```
The atomic output of every routing decision. Every path through the router terminates in one of these two values.

### 2.2 `RoutingDecision` (value object)
```dart
class RoutingDecision {
  final ApiDecision api;          // The wire protocol chosen
  final double confidence;        // 0.0 – 1.0 certainty score
  final String reasoning;         // Human-readable explanation
  final bool modeConflict;        // True if Green ≠ Performance on this context
  final bool isCacheHit;          // True if answer came from SQLite cache
  final String aiDecisionSource;  // "gemini_live" | "cached" | "rules_engine"
}
```
This object is the contract between the router and the rest of the system. Every code path must produce one.

### 2.3 `ApiRequestLog` (telemetry row)
Each completed API call produces an `ApiRequestLog` written to the in-memory `ApiHistoryProvider`. Fields relevant to routing feedback:

| Field | Role |
|---|---|
| `durationMs` | Actual measured latency |
| `joulesEstimated` | `EnergyEstimator` output |
| `modeConflict` | Green/Performance disagreement flag |
| `aiDecisionSource` | Provenance of the routing decision |
| `aiReasoning` | Gemini's one-sentence rationale |
| `deviceTier` | Hardware tier at call time |
| `networkType` | `wifi` / `4g` / `none` / `unknown` |

### 2.4 `RoutingRecord` (persistent telemetry)
A serialisable superset of `ApiRequestLog` written to `RoutingHistoryStore` (SharedPreferences). Used by the Balanced mode to pass the last 8 records of a payload type to Gemini as empirical priors.

---

## 3. Device Profiling Subsystem

**File:** `lib/routing/device_profiler.dart`

### 3.1 `DeviceTier` enum
```dart
enum DeviceTier { budget, mid, flagship }
```

### 3.2 Classification Algorithm

`DeviceProfiler.getDeviceTier()` is called once at startup; the result is **session-cached** to avoid repeated `platform_channel` overhead.

```
Algorithm: classifyDevice()

  Input:  androidInfo.physicalRamSize (bytes), or Platform.isIOS

  If Platform.isIOS:
    → tier = flagship   // iOS devices universally treated as high-end

  If Platform.isAndroid:
    totalRamGb = physicalRamSize / (1024³)

    if totalRamGb < 4.0  → tier = budget
    if totalRamGb ≤ 8.0  → tier = mid
    if totalRamGb > 8.0  → tier = flagship

  If physicalRamSize ≤ 0 (device reports 0 — some emulators):
    → tier = mid         // Safe fallback

  Cache result for session lifetime.
```

**Why RAM?** RAM is the best single proxy for SoC generation and overall CPU/GPU efficiency on Android without requiring privileged system access. Higher RAM almost always correlates with a more capable, lower-wattage-per-operation chip.

### 3.3 Device Signature
`getDeviceSignature()` returns a human-readable string — e.g. `"samsung SM-A525F (mt6768, 6.0 GB RAM)"` — which is passed directly to Gemini in the AI Agent Dashboard prompt, giving the LLM concrete hardware context for its policy generation.

---

## 4. Energy Estimation Model

**File:** `lib/services/energy_estimator.dart`

The system uses a **linear power model** derived from PowerAPI labelling conventions:

```
Joules = Wattage_tier × (durationMs / 1000)
```

| Device Tier | Prior Wattage (W) | Source Convention |
|---|---|---|
| `budget` | 0.80 W | PowerAPI — budget Android device label |
| `mid` | 0.60 W | PowerAPI — mid-range label |
| `flagship` | 0.45 W | PowerAPI — flagship label |

**Key insight for the paper:** A budget device running a short REST call may consume *more* Joules than a flagship running a longer GraphQL call, because the budget wattage prior is significantly higher (0.80 W vs 0.45 W). This means the API choice that minimises energy is **device-tier dependent**, not request-type dependent alone. Data rows include the `Device_Tier` column so this effect can be isolated in the analysis.

The formula does **not** model idle baseline power, screen-on draw, or radio startup cost (these are assumed constant-per-call and cancel in comparative analysis).

---

## 5. Routing Strategies Overview

The global `currentRoutingStrategy` selects among five strategies processed by `AdaptiveApiService._executeWithRouting()`:

| Strategy Value | Behaviour |
|---|---|
| `"rest"` | Always REST, no routing logic |
| `"graphql"` | Always GraphQL, no routing logic |
| `"default"` | Both protocols called in parallel (comparison baseline) |
| `"heuristic"` | Phase-1 REST baseline → Phase-2 latency-winner |
| `"ai_power"` | Full `ConsciousRouter` pipeline (Green / Performance / Balanced) |

Only `"ai_power"` engages the three modes described in this document.

---

## 6. Green Mode — Algorithm Deep Dive

**Goal:** Choose the wire protocol that consumes the fewest estimated Joules for this `(requestType, deviceTier, networkType)` context.

### 6.1 Step 1 — History-First Energy Comparison

`_pickGreenPhilosophy()` queries `ApiHistoryProvider` for **session-average Joules** for the current `requestType`:

```
jRest = averageJoulesEstimated(requestType, 'REST')
jGql  = averageJoulesEstimated(requestType, 'GRAPHQL')
```

Decision table:

| jRest | jGql | Decision |
|---|---|---|
| not null | not null | Pick lower Joules; tie → REST |
| not null | null | REST (only evidence available) |
| null | not null | GraphQL (only evidence available) |
| null | null | Fall through to tier-based fallback |

### 6.2 Step 2 — Tier-Based Static Fallback

When no history exists for the current `requestType`, `_greenTierFallback()` applies a **payload-size × device-tier matrix**:

```
Algorithm: _greenTierFallback(requestType, tier)

  "simple_list"   → REST always
      Rationale: Small payload (~2 KB). GraphQL parsing overhead
                 costs more CPU energy than REST's minor over-fetch.

  "detail_medium" → flagship → GraphQL
                    budget/mid → REST
      Rationale: Medium payload (~15 KB). Flagship devices parse
                 faster per Joule. Budget devices pay a higher
                 wattage penalty for the extra CPU cycles.

  "nested_large"  → flagship → GraphQL
  "ultra_all"     → budget/mid → REST
      Rationale: Large payloads (~150 KB). GraphQL reduced transfer
                 wins on flagship. Budget devices cannot amortize the
                 parser cost efficiently.

  default         → REST
```

### 6.3 Step 3 — Cache Check & Persistence

Before the rules engine runs, `_applyGreenMode()` computes a **SHA-256 cache key**:

```
cacheKey = SHA256("simple_list|green|flagship|wifi")
```

If the key resolves in `AiPolicyStore` (SQLite), the cached `(route, reasoning)` is returned immediately with `confidence = 1.0` and `aiDecisionSource = "cached"`. Otherwise the rules-engine result is persisted to the store before returning.

### 6.4 Output

```dart
RoutingDecision(
  api: greenPick,        // REST or GraphQL
  confidence: 0.95,      // High; rules-engine certainty
  reasoning: "Green Mode: minimize Joules on this device; chosen REST for simple_list (history + tier fallback).",
  modeConflict: <bool>,
  isCacheHit: false,
  aiDecisionSource: 'rules_engine',
)
```

---

## 7. Performance Mode — Algorithm Deep Dive

**Goal:** Choose the wire protocol that returns the response in the fewest milliseconds.

### 7.1 Step 1 — Network Quality + Server Load Priority Rules

`_pickPerformancePhilosophy()` applies **hard priority overrides** before consulting history:

```
Algorithm: _pickPerformancePhilosophy(requestType, networkType, serverLoad)

  Priority 1 (highest):
    if serverLoad == 'high' AND requestType == 'simple_list':
      → REST
      Rationale: Under high server load, GraphQL's single-endpoint
                 resolver chain adds queuing delay. REST scatters
                 load across multiple lightweight endpoints.

  Priority 2:
    if NOT wifi (i.e., mobile/none) AND requestType IN {simple_list, detail_medium}:
      → REST
      Rationale: Mobile links have higher RTT variance. REST's simple
                 GET requests have a smaller "cold" overhead per
                 round-trip than GraphQL's POST + body parsing.

  Priority 3:
    if wifi AND requestType IN {nested_large, ultra_all}:
      → GraphQL
      Rationale: On a fast link, GraphQL's ability to fetch only
                 required fields eliminates multiple round-trips
                 needed by REST, improving raw speed.
```

### 7.2 Step 2 — Latency-History Comparison

If no priority rule fires, the algorithm consults `ApiHistoryProvider`:

```
msRest = averageLatencyMs(requestType, 'REST')
msGql  = averageLatencyMs(requestType, 'GRAPHQL')

if both present: pick lower ms (tie → REST)
if only msRest:  REST
if only msGql:   GraphQL
if neither:      REST (safe default)
```

### 7.3 Server Load Signal

`ServerLoadService.getServerLoad()` issues a `GET /api/load` request to the Flask backend with a **500 ms timeout**. The backend returns `{"load": "low"|"medium"|"high"}`. If the request fails or times out, the default `"medium"` is assumed, which does not trigger any hard override.

### 7.4 Output

```dart
RoutingDecision(
  api: perfPick,
  confidence: 0.95,
  reasoning: "Performance Mode: minimize Duration_ms; chosen REST for simple_list (latency history + network/load heuristics).",
  modeConflict: <bool>,
  isCacheHit: false,
  aiDecisionSource: 'rules_engine',
)
```

---

## 8. Balanced (AI) Mode — Algorithm Deep Dive

**Goal:** Reach a contextually optimal compromise between energy and latency using Google Gemini as the decision-making agent.

### 8.1 Architectural Position

Balanced Mode is the **only mode that calls Gemini per routing event**. Green and Performance modes are pure rules engines; Balanced mode is a hybrid that feeds the deterministic outputs of both engines into Gemini as *hints*, along with raw empirical measurements and device context.

### 8.2 Complete Algorithm

```
Algorithm: _applyBalancedMode(requestType, deviceTier, networkType,
                               batteryLevel, serverLoad,
                               greenPick, perfPick, modeConflict)

  ─── Phase A: Cache Hit Check ────────────────────────────────────────
  cacheKey = SHA256(requestType | "balanced" | deviceTier | networkType)
  cached   = AiPolicyStore.get(cacheKey)

  if cached ≠ null:
    return RoutingDecision(
      api             = parseRoute(cached.route),
      confidence      = 1.0,
      reasoning       = cached.reasoning,
      aiDecisionSource = "cached"
    )
    ↳ Exits here. No Gemini call made.

  ─── Phase B: Empirical Data Collection ──────────────────────────────
  jRest  = ApiHistoryProvider.averageJoulesEstimated(requestType, 'REST')
  jGql   = ApiHistoryProvider.averageJoulesEstimated(requestType, 'GRAPHQL')
  msRest = ApiHistoryProvider.averageLatencyMs(requestType, 'REST')
  msGql  = ApiHistoryProvider.averageLatencyMs(requestType, 'GRAPHQL')

  lastHistory = RoutingHistoryStore.getLastRecords(requestType, N=8)
    → List of up to 8 recent {api, joules, latency_ms} tuples
      (provides Gemini with temporal trend, not just averages)

  ─── Phase C: Philosophy Hints ───────────────────────────────────────
  greenHint   = routeString(greenPick)   // "REST" or "GraphQL"
  perfHint    = routeString(perfPick)
  conflictHint = modeConflict
               ? "CONFLICT (research-relevant disagreement)"
               : "agree"

  ─── Phase D: Prompt Construction ────────────────────────────────────
  balancedPhilosophy = """
    BALANCED MODE — Conscious compromise (not pure Green nor pure Performance).
    - You receive both energy history (Joules_estimated) and latency history (Duration_ms).
    - Resolve the trade-off: if energy and latency disagree, prefer the greener
      option when the relative gap in BOTH dimensions is under 10%
      (small trade-off → default to environmental benefit).
    - When one option is clearly better on one dimension and much worse on the
      other, weigh device_tier, battery_level, network quality, and server_load.
    - Green-only routing would pick: {greenHint}
    - Performance-only would pick:   {perfHint}
    - They {conflictHint}.
  """

  context = JSON({
    payload_type:             requestType,       // "simple_list" | etc.
    device_tier:              deviceTier.name,   // "budget" | "mid" | "flagship"
    network_type:             networkType,       // "wifi" | "4g" | "none"
    battery_level:            batteryLevel,      // integer percent 0-100
    server_load:              serverLoad,        // "low" | "medium" | "high"
    avg_joules_rest:          jRest,             // nullable double
    avg_joules_graphql:       jGql,              // nullable double
    avg_latency_ms_rest:      msRest,            // nullable double
    avg_latency_ms_graphql:   msGql,             // nullable double
    green_philosophy_pick:    greenHint,
    performance_philosophy_pick: perfHint,
    philosophies_conflict:    modeConflict,
    recent_samples:           lastHistory        // [{api, joules, latency}×8]
  })

  prompt = balancedPhilosophy
           + "\n\nContext: " + jsonEncode(context)
           + "\n\nRespond ONLY with valid JSON, no markdown:\n"
           + '{"route":"REST" or "GraphQL","confidence":0.0 to 1.0,"reasoning":"one sentence max"}'

  ─── Phase E: Gemini API Call with Retry ─────────────────────────────
  retries = 0
  while retries < 2:
    try:
      response = Gemini.generateContent([Content.text(prompt)])
      jsonStr  = stripMarkdownFences(response.text)
      data     = jsonDecode(jsonStr)

      decision = RoutingDecision(
        api             = data["route"] == "GRAPHQL" ? graphql : rest,
        confidence      = data["confidence"],    // float from Gemini
        reasoning       = data["reasoning"],     // one-sentence rationale
        modeConflict    = modeConflict,
        isCacheHit      = false,
        aiDecisionSource = "gemini_live"
      )

      ─── Phase F: Persist to Cache ───────────────────────────────────
      AiPolicyStore.put(cacheKey, route, reasoning)

      return decision

    catch 429 / quota error:
      retries++
      sleep(2 seconds)
      continue

    catch other error:
      ─── Phase G: Error Fallback ─────────────────────────────────────
      return RoutingDecision(
        api             = greenPick,    // Conservative fallback
        confidence      = 0.5,
        reasoning       = "Gemini error; Green-philosophy fallback.",
        aiDecisionSource = "rules_engine"
      )

  ─── Phase H: Exhausted Retry Fallback ───────────────────────────────
  return RoutingDecision(
    api             = greenPick,
    confidence      = 0.5,
    reasoning       = "Balanced fallback: no Gemini response; using Green-philosophy pick.",
    aiDecisionSource = "rules_engine"
  )
```

### 8.3 The 10% Threshold Rule (Balanced Philosophy)

The prompt instructs Gemini to apply a **10% relative gap heuristic**:

> *"If energy and latency disagree, prefer the greener option when the relative gap in **both** dimensions is under 10%."*

This encodes the research position: **when trade-offs are marginal, environmental benefit should be the tiebreaker**. Only when one protocol is clearly dominant on one axis and significantly worse on the other should Gemini deviate from the green choice.

### 8.4 Inputs to Gemini — Full Taxonomy

| Input Field | Type | Source | Role |
|---|---|---|---|
| `payload_type` | string | call context | Identifies query complexity |
| `device_tier` | enum string | `DeviceProfiler` | Wattage prior, parsing speed |
| `network_type` | string | `connectivity_plus` | RTT quality, radio energy |
| `battery_level` | int % | `battery_plus` | Low battery → bias green |
| `server_load` | string | `GET /api/load` | High load → REST may be faster |
| `avg_joules_rest` | nullable float | `ApiHistoryProvider` | Empirical energy for REST |
| `avg_joules_graphql` | nullable float | `ApiHistoryProvider` | Empirical energy for GraphQL |
| `avg_latency_ms_rest` | nullable float | `ApiHistoryProvider` | Empirical latency for REST |
| `avg_latency_ms_graphql` | nullable float | `ApiHistoryProvider` | Empirical latency for GraphQL |
| `green_philosophy_pick` | string | `_pickGreenPhilosophy()` | Deterministic green answer |
| `performance_philosophy_pick` | string | `_pickPerformancePhilosophy()` | Deterministic perf answer |
| `philosophies_conflict` | bool | computed | Research-relevant signal |
| `recent_samples` | JSON array (≤8) | `RoutingHistoryStore` | Temporal trend for Gemini |

### 8.5 Gemini Output Contract

Gemini is constrained to return exactly:
```json
{"route": "REST", "confidence": 0.82, "reasoning": "Low battery on mid-tier device favors REST's lower parse overhead despite GraphQL's smaller payload."}
```

The `confidence` field is directly propagated to the benchmark UI and CSV export, allowing confidence-stratified analysis in the research data.

### 8.6 `aiDecisionSource` Provenance Values

| Value | Meaning |
|---|---|
| `"gemini_live"` | Fresh Gemini call this session |
| `"cached"` | Returned from SQLite AiPolicyStore |
| `"rules_engine"` | Gemini unavailable; fallback to Green philosophy |

This field is included in both the CSV export and the `ApiRequestLog`, allowing the paper to filter rows by decision provenance.

---

## 9. AI Policy Cache (AiPolicyStore)

**File:** `lib/routing/ai_policy_store.dart`

### 9.1 Purpose

Gemini calls have latency (~500–2000 ms) and cost quota. The cache eliminates repeat calls for **identical contexts** within and across sessions.

### 9.2 Storage Backend

SQLite via `sqflite` package. Database file: `ai_routing_policy.db`.

```sql
CREATE TABLE policy (
  cache_key  TEXT PRIMARY KEY,   -- SHA-256 hex string
  route      TEXT NOT NULL,      -- "REST" or "GraphQL"
  reasoning  TEXT NOT NULL,      -- Gemini's explanation
  created_at TEXT NOT NULL       -- ISO-8601 timestamp
)
```

### 9.3 Cache Key Construction

```dart
static String computeKey({
  required String payloadType,
  required String mode,
  required String deviceTier,
  required String networkType,
}) {
  final raw = '$payloadType|$mode|$deviceTier|$networkType';
  return sha256.convert(utf8.encode(raw)).toString();
}
```

**Why SHA-256?** The tuple `(payloadType, mode, deviceTier, networkType)` fully identifies the *structural* context. Battery level is intentionally **excluded** from the key — a low-battery event should not create a separate cache entry, since battery level is passed to Gemini as a soft signal, not a structural input. This keeps the cache size bounded.

### 9.4 Cache Invalidation Strategy

No automatic TTL is implemented. The cache is **manually cleared** via the Settings screen (research convenience: allows re-running fresh Gemini decisions for a new experiment session).

---

## 10. Heuristic Learning Phase

**File:** `lib/routing/heuristic_learning_store.dart`

When `currentRoutingStrategy = "heuristic"`, the system operates in two distinct phases before resorting to any AI:

### 10.1 Phase 1: Baseline Collection (Learning Phase)

```
while count(REST_samples[requestType]) < baselineTarget (=10):
  → Force REST for all calls of requestType
  → Record actual latency_ms to _restLatenciesMs[requestType]
  → Persist to SharedPreferences
```

This ensures a minimum of 10 measurements per payload type before any comparison decision is made.

### 10.2 Phase 2: Protocol Competition (Post-Learning)

```
restAvg = HeuristicLearningStore.averageRestMs(requestType)
gqlAvg  = ApiHistoryProvider.averageLatencyMs(requestType, 'GRAPHQL')
         ?? double.infinity   ← GraphQL wins only if measured

if gqlAvg < restAvg:
  → GraphQL
else:
  → REST
```

The `double.infinity` sentinel ensures REST is preferred when no GraphQL history exists, preventing premature switches.

---

## 11. AdaptiveApiService — The Dispatcher

**File:** `lib/services/service_locator.dart`

`AdaptiveApiService._executeWithRouting()` is the central dispatch function. For `strategy = "ai_power"`, it orchestrates the full timing pipeline:

```
t₀ = DateTime.now()
decision = await ConsciousRouter.instance.route(requestType)
t₁ = DateTime.now()
routingOverheadMs = t₁ - t₀          // Time spent in routing (includes Gemini call)

Set ApiCallContext.aiDecisionSource, reasoning, modeConflict

Show RoutingOverlay (HUD on screen)

selectedService = decision.api == graphql ? graphqlApiService : restApiService

t₂ = DateTime.now()
result = await action(selectedService, routingOverheadMs)
t₃ = DateTime.now()
executionDurationMs = t₃ - t₂        // Actual API wire time (separate from routing)

await ConsciousRouter.instance.logFinalOutcome(requestType, decision, executionDurationMs)

return result
```

**Critical separation:** `routingOverheadMs` (Gemini latency + routing logic) and `executionDurationMs` (wire protocol latency) are measured and recorded **independently**. This allows the paper to distinguish the cost of routing intelligence from the cost it is optimising.

---

## 12. Data Collection & Provenance

Every API call (successful or failed) produces an `ApiRequestLog` row. The fields used in CSV export for the research paper:

| CSV Column | Source |
|---|---|
| `Timestamp` | `DateTime.now()` at call completion |
| `Payload_Type` | `requestType` string |
| `Protocol` | `REST` or `GraphQL` |
| `Duration_ms` | Measured wall-clock wire time |
| `Routing_Overhead_ms` | Gemini + router decision time |
| `Size_KB` | Response body size |
| `Joules_Estimated` | `EnergyEstimator.estimateJoules(durationMs)` |
| `Device_Tier` | `DeviceProfiler` classification |
| `Network_Type` | `connectivity_plus` result |
| `Operating_Mode` | `green` / `performance` / `balanced` |
| `Routing_Strategy` | `ai_power` / `heuristic` / etc. |
| `AI_Decision_Source` | `gemini_live` / `cached` / `rules_engine` |
| `AI_Reasoning` | Gemini's one-sentence rationale |
| `Mode_Conflict` | Boolean green ≠ performance disagreement |

---

## 13. Mode Conflict Signal

`modeConflict` is computed at the start of every `route()` call:

```dart
final greenPick = _pickGreenPhilosophy(requestType, deviceTier, networkType);
final perfPick  = _pickPerformancePhilosophy(requestType, networkType, serverLoad);
final modeConflict = greenPick != perfPick;
```

This flag is a **research-first signal** — it marks rows where the green and performance objectives genuinely disagree. These rows are the most analytically interesting for the paper because they reveal the actual trade-off landscape. Every mode propagates `modeConflict` unchanged to the `RoutingDecision` and ultimately to the CSV.

---

## 14. Full Routing Execution Flow (end-to-end)

```
User Action → UI layer
     │
     ▼
AdaptiveApiService._executeWithRouting(requestType)
     │
     ├─ strategy = "rest"     → RestApiService (direct)
     ├─ strategy = "graphql"  → GraphQlApiService (direct)
     ├─ strategy = "default"  → ComparisonApiService (REST + GQL parallel)
     ├─ strategy = "heuristic"→ HeuristicLearningStore phase check → REST or GQL
     └─ strategy = "ai_power" ──────────────────────────────────────────────────┐
                                                                                │
ConsciousRouter.route(requestType)                                             │
     │                                                                         │
     ├─ DeviceProfiler.getDeviceTier()    [cached after first call]            │
     ├─ connectivity_plus.checkConnectivity()  [realtime]                      │
     ├─ ServerLoadService.getServerLoad()      [GET /api/load, 500ms timeout]  │
     │                                                                         │
     ├─ _pickGreenPhilosophy()  →  greenPick                                  │
     ├─ _pickPerformancePhilosophy() → perfPick                               │
     ├─ modeConflict = (greenPick ≠ perfPick)                                 │
     │                                                                         │
     └─ switch(currentOperatingMode):                                          │
           "green"       → _applyGreenMode()                                  │
                            └─ cache check → rules engine → cache store       │
           "performance" → _applyPerformanceMode()                            │
                            └─ cache check → rules engine → cache store       │
           "balanced"    → _applyBalancedMode()                               │
                            └─ cache check                                    │
                               └─ miss: build Gemini prompt                   │
                                        → Gemini API call (retry ≤2×)        │
                                        → parse JSON response                 │
                                        → store in AiPolicyStore              │
                                        → return RoutingDecision              │
                                                                              │
                                                            RoutingDecision   │
                                                                  ↓           │
ApiCallContext ← aiDecisionSource, reasoning, modeConflict                   │
RoutingOverlay.show()  ← HUD notification to user                            │
selectedService ← REST or GraphQL                                             │
     │
     ▼
API call executed → response received
     │
ConsciousRouter.logFinalOutcome()
     ├─ EnergyEstimator.estimateJoules(executionDurationMs)
     ├─ RoutingHistoryStore.addRecord(RoutingRecord)   [SharedPreferences, ≤100 rows]
     └─ ApiHistoryProvider.addLog(...)                 [in-memory, feeds future routing]
     │
     ▼
UI updated, row available in benchmark history + CSV export
```

---

## 15. Research Fairness Note

The system records `Device_Tier` on every row so the paper can state the following paradox honestly:

> *"A flagship device in Green Mode can show lower Joule consumption than a budget device running the same API call via the same mode, because hardware efficiency differs between tiers. Green tooling therefore often helps least those who need it most, unless routing logic explicitly compensates for device tier."*

The Green Mode tier-based fallback (`_greenTierFallback`) is the direct mitigation: it routes budget devices to REST for medium and large payloads, specifically because GraphQL's CPU parsing overhead is energetically expensive on underpowered hardware. This is a deliberate, documented design choice with ethical and fairness implications for green software research.

---

*Document generated from source code analysis of `/lib/routing/` and `/lib/services/` — April 2026.*
