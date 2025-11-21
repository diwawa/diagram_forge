Below is a **ready-to-use Elixir seeds snippet** with **25 diagrams**.

* Each entry has: `title`, `slug`, `domain`, `level`, `tags`, `format`, `diagram_source`, `summary`, `notes_md`.
* `diagram_source` is **pure Mermaid** (no backticks).
* You can drop this into `priv/repo/seeds.exs` (or a separate module) and adapt to your schema names.

---

```elixir
diagrams = [
  %{
    title: "GenServer Call vs Cast",
    slug: "genserver-call-vs-cast",
    domain: "elixir",
    level: :intermediate,
    tags: ["elixir", "genserver", "otp", "concurrency"],
    format: :mermaid,
    diagram_source: """
    sequenceDiagram
      participant C as Caller
      participant G as GenServer

      C->>G: call(request)
      G-->>C: reply(response)

      C-)G: cast(message)
      Note right of G: Cast is async, no reply

      C->>G: call(long_op)
      Note over C,G: Caller blocks until GenServer replies
    """,
    summary: "Illustrates the difference between synchronous call and asynchronous cast in a GenServer.",
    notes_md: """
    - `call/2` is synchronous and expects a reply.
    - `cast/2` is asynchronous and returns immediately.
    - Use `call` when the caller needs a result; use `cast` for fire-and-forget updates.
    """
  },
  %{
    title: "OTP Supervision Tree Basics",
    slug: "otp-supervision-tree-basics",
    domain: "elixir",
    level: :intermediate,
    tags: ["elixir", "otp", "supervision", "fault-tolerance"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      R[Application Root Supervisor]
      R --> S1[Supervisor: one_for_one]
      R --> S2[Supervisor: rest_for_one]

      S1 --> A[GenServer A]
      S1 --> B[GenServer B]

      S2 --> C[GenServer C]
      S2 --> D[GenServer D]

      classDef sup fill:#1f2933,stroke:#4b5563,color:#e5e7eb;
      class R,S1,S2 sup;
    """,
    summary: "Shows a basic OTP supervision tree with different restart strategies.",
    notes_md: """
    - Root supervisor starts sub-supervisors and workers.
    - `one_for_one`: only the crashed child is restarted.
    - `rest_for_one`: crashed child and all children started after it are restarted.
    - Supervision trees isolate failures and keep the system resilient.
    """
  },
  %{
    title: "Fault Tolerance in Elixir Processes",
    slug: "fault-tolerance-elixir-processes",
    domain: "elixir",
    level: :intermediate,
    tags: ["elixir", "otp", "fault-tolerance", "supervision"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      Client[Client Process]
      W[Worker Process]
      S[Supervisor]

      Client -->|request| W
      W -->|crash| X((Exit Signal))
      X --> S
      S -->|restart| W2[New Worker Process]

      Note right of W2: State restored via init/1
    """,
    summary: "Demonstrates how supervisors detect worker crashes and restart them.",
    notes_md: """
    - Workers are allowed to crash instead of handling every error.
    - Supervisors trap exits and apply a restart strategy.
    - Faults are isolated to failing processes, protecting the rest of the system.
    """
  },
  %{
    title: "Kafka + Broadway Event-Driven Processing",
    slug: "kafka-broadway-event-driven",
    domain: "elixir",
    level: :intermediate,
    tags: ["kafka", "broadway", "events", "streaming"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      P[Producers<br/>Order Events] --> K[(Kafka Topic<br/>orders)]
      K --> CG[Consumer Group<br/>Broadway Pipeline]

      CG --> ST1[Stage 1:<br/>Deserialize & Validate]
      ST1 --> ST2[Stage 2:<br/>Enrich with Inventory]
      ST2 --> ST3[Stage 3:<br/>Publish ML Features]

      ST3 --> FS[Feature Store]
      ST3 --> DB[(Postgres)]
    """,
    summary: "Shows how Kafka and Broadway work together to process event streams and feed ML features.",
    notes_md: """
    - Producers write order events into a Kafka topic.
    - Broadway consumers read from Kafka, process in stages, and handle backpressure.
    - Enriched data is written to a feature store and Postgres for downstream ML and analytics.
    """
  },
  %{
    title: "Prediction-Serving API with Fallback Logic",
    slug: "prediction-serving-api-fallback",
    domain: "ml",
    level: :advanced,
    tags: ["ml", "api", "fallback", "resilience"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      C[Client Service] --> API[Prediction API]

      API -->|cache lookup| Cache[(Prediction Cache)]
      Cache -->|hit| R1[Return Cached Prediction]

      API -->|miss| VAI[Cloud ML Service<br/>Vertex/Modal]
      VAI -->|success| R2[Return Fresh Prediction]
      VAI -->|failure/timeout| F[Fallback Logic]

      F --> ETS[(Local Heuristics<br/>or Rule Engine)]
      ETS --> R3[Return Fallback Prediction]

      R2 --> Cache
    """,
    summary: "Describes a resilient prediction-serving API with cache, cloud ML, and local fallback.",
    notes_md: """
    - Check cache first to avoid unnecessary ML calls.
    - On cache miss, call the cloud ML service.
    - If ML service fails or times out, use a local heuristic or last-known-good value.
    - Successful predictions are written back to the cache.
    """
  },
  %{
    title: "Cloud ML Inference Flow with Vertex AI",
    slug: "cloud-ml-inference-vertex-ai",
    domain: "ml",
    level: :intermediate,
    tags: ["vertex-ai", "gcp", "ml", "inference"],
    format: :mermaid,
    diagram_source: """
    sequenceDiagram
      participant S as Elixir Service
      participant FG as Feature Store/DB
      participant V as Vertex AI Endpoint

      S->>FG: Fetch features for entity
      FG-->>S: Feature vector

      S->>V: HTTP/JSON predict(features)
      V-->>S: Prediction result

      S->>S: Apply business rules
      S-->>Caller: Response with prediction
    """,
    summary: "Shows how an Elixir service calls a Vertex AI endpoint using features from a store.",
    notes_md: """
    - Service loads feature vectors from a feature store or DB.
    - Sends features to a Vertex AI endpoint for prediction.
    - Applies domain-specific rules before returning to the caller.
    - Latency and error handling are critical at each step.
    """
  },
  %{
    title: "Edge vs Cloud Inference Architecture",
    slug: "edge-vs-cloud-inference",
    domain: "ml",
    level: :intermediate,
    tags: ["edge", "cloud", "inference", "latency"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      Client[Client Request] --> GW[Inference Gateway]

      GW --> E[Edge Model<br/>Cloudflare Workers/Edge]
      E -->|fast success| R1[Return Edge Prediction]

      E -->|not available/low confidence| CML[Cloud ML Service]
      CML -->|success| R2[Return Cloud Prediction]

      CML -->|failure| F[Fallback (Cache/Heuristics)]
    """,
    summary: "Compares edge inference with cloud inference and how a gateway chooses between them.",
    notes_md: """
    - Edge inference offers lower latency but may use smaller or specialized models.
    - Cloud inference offers higher accuracy or more complex models.
    - Gateway decides based on availability, confidence, or cost.
    - Fallbacks protect user experience when both paths fail.
    """
  },
  %{
    title: "Demand Forecasting API Architecture",
    slug: "demand-forecasting-api-architecture",
    domain: "logistics",
    level: :intermediate,
    tags: ["demand-forecasting", "api", "logistics", "ml"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      UI[Internal Tools / Services] --> API[Demand Forecasting API]

      API --> FT[Feature Builder]
      FT --> HDB[(Historical Orders)]
      FT --> INV[(Inventory & Lead Times)]

      FT --> ML[Forecasting Model<br/>(Vertex/Modal)]
      ML --> FC[Forecast Results]

      FC --> API
      FC --> DB[(Forecast DB)]
      FC --> BI[BI Dashboards]
    """,
    summary: "Shows the components involved in serving demand forecasts via an API.",
    notes_md: """
    - API receives forecast requests for SKUs/locations/time ranges.
    - Feature builder combines historical orders, inventory, and lead-time data.
    - Forecasting model returns predicted demand.
    - Results are persisted for BI and re-use.
    """
  },
  %{
    title: "Intelligent Routing ML Pipeline",
    slug: "intelligent-routing-ml-pipeline",
    domain: "logistics",
    level: :advanced,
    tags: ["routing", "logistics", "ml", "optimization"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      O[Orders & Destinations] --> FP[Feature Pipeline]
      WH[Warehouse Data] --> FP
      SH[Carrier/Shipping Rates] --> FP

      FP --> M[Routing Model]
      M --> R[Ranked Route Options]

      R --> ES[Execution Service]
      ES --> OMS[(Order Management)]
      ES --> WMS[(Warehouse Management)]
    """,
    summary: "Illustrates a pipeline that generates ML-based routing recommendations for logistics.",
    notes_md: """
    - Features combine order data, warehouse capabilities, and carrier rates.
    - Model outputs ranked route options or scores.
    - Execution service chooses a route and updates OMS/WMS.
    - Feedback from actual performance can be fed back into training.
    """
  },
  %{
    title: "Supply Chain Anomaly Detection Loop",
    slug: "supply-chain-anomaly-detection",
    domain: "logistics",
    level: :intermediate,
    tags: ["anomaly-detection", "monitoring", "logistics"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      E[Events<br/>Shipments, Scans, Delays] --> SP[Streaming Pipeline]
      SP --> FE[Feature Extraction]
      FE --> AD[Anomaly Detection Model]

      AD -->|normal| NS[No Alert]
      AD -->|anomaly| AL[Alert Service]

      AL --> OP[Ops Dashboard]
      AL --> NT[Notifications<br/>(Email/SMS/Webhook)]
    """,
    summary: "Shows how operational events are monitored for anomalies in a supply chain.",
    notes_md: """
    - Event stream includes tracking scans, delays, inventory changes.
    - Features capture deviations from expected timelines or volumes.
    - Model flags anomalies which trigger alerts to ops teams.
    - Feedback on false positives can improve the model.
    """
  },
  %{
    title: "Caching ML Predictions with ETS and Redis",
    slug: "caching-ml-predictions-ets-redis",
    domain: "elixir",
    level: :intermediate,
    tags: ["caching", "ets", "redis", "ml"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      C[Caller] --> S[Prediction Service]

      S --> ETS[(ETS In-Memory Cache)]
      ETS -->|hit| R1[Return Cached Prediction]

      ETS -->|miss| RDS[(Redis Cache)]
      RDS -->|hit| R2[Return Redis Prediction]
      RDS -->|miss| ML[ML Service]

      ML --> R3[Return New Prediction]
      R3 --> ETS
      R3 --> RDS
    """,
    summary: "Describes a two-level caching strategy for ML predictions using ETS and Redis.",
    notes_md: """
    - ETS provides very fast in-memory cache on each BEAM node.
    - Redis offers a shared distributed cache across nodes.
    - Cache lookup is layered: ETS → Redis → ML Service.
    - Positive responses are written back to both caches.
    """
  },
  %{
    title: "Rate Limiting LLM API Requests",
    slug: "rate-limiting-llm-api-requests",
    domain: "infra",
    level: :intermediate,
    tags: ["llm", "rate-limiting", "api-gateway"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      C[Internal Services] --> GW[LLM Gateway]
      GW --> RL[Rate Limiter<br/>(Token Bucket)]
      RL --> Q[Request Queue]
      Q --> LLM[LLM Provider<br/>OpenAI/Anthropic]

      RL -->|limit exceeded| F[Fast Fail / Fallback]
    """,
    summary: "Shows how a gateway can apply rate limiting before forwarding LLM requests.",
    notes_md: """
    - Gateway centralizes access to external LLM providers.
    - Rate limiter enforces global or per-tenant quotas.
    - Requests above the limit are rejected quickly or routed to fallbacks.
    - Queue smooths bursts while respecting provider limits.
    """
  },
  %{
    title: "Semantic Search with Embeddings and Vector DB",
    slug: "semantic-search-embeddings-vector-db",
    domain: "ml",
    level: :intermediate,
    tags: ["embeddings", "vector-db", "semantic-search"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      DOCS[Documents/Records] --> EG[Embedding Generator]
      EG --> VDB[(Vector DB)]

      Q[User Query] --> QE[Query Embedding]
      QE --> VDB
      VDB --> RES[Top-k Similar Items]

      RES --> APP[Application / LLM]
    """,
    summary: "Explains how semantic search works using embeddings stored in a vector database.",
    notes_md: """
    - Off-line pipeline embeds documents and stores vectors in a vector DB.
    - At query time, the query is also embedded.
    - Vector DB performs nearest-neighbor search to find similar items.
    - Results can be used directly or as context for an LLM.
    """
  },
  %{
    title: "Observability Pipeline for ML-Powered Services",
    slug: "observability-pipeline-ml-services",
    domain: "infra",
    level: :intermediate,
    tags: ["observability", "logging", "metrics", "tracing"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      SVC[Elixir Services] --> L[Logs]
      SVC --> M[Metrics]
      SVC --> T[Traces]

      L --> LOG[(Log Store<br/>e.g. Loki/ELK)]
      M --> TS[(Time-Series DB<br/>Prometheus)]
      T --> TP[(Tracing Backend<br/>Jaeger/Tempo)]

      LOG --> DASH[Dashboards & Alerts]
      TS --> DASH
      TP --> DASH
    """,
    summary: "Shows how logs, metrics, and traces flow from services into observability backends.",
    notes_md: """
    - Services emit structured logs, metrics, and traces.
    - Logs help with debugging; metrics with SLOs and alerts; traces with request flows.
    - Dashboards aggregate data and trigger alerts to on-call engineers.
    """
  },
  %{
    title: "Circuit Breaker and Retry Around ML Calls",
    slug: "circuit-breaker-retry-ml-calls",
    domain: "infra",
    level: :intermediate,
    tags: ["resilience", "circuit-breaker", "retries", "ml"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      C[Caller] --> CB[Circuit Breaker]
      CB -->|closed| ML[ML Service]
      CB -->|open| FB[Fallback Response]

      ML -->|success| S[Store Success Metrics]
      ML -->|failure| RT[Retry with Backoff]

      RT -->|max retries exceeded| E[Record Error & Trip Breaker]
      E --> CB
    """,
    summary: "Illustrates how a circuit breaker and retry strategy protect services calling ML endpoints.",
    notes_md: """
    - Circuit breaker starts closed and forwards calls to ML service.
    - Repeated failures trip the breaker to open state, short-circuiting calls.
    - Retries use exponential backoff to avoid hammering the provider.
    - Fallback responses protect user experience during outages.
    """
  },
  %{
    title: "Real-Time Data Pipeline Feeding ML Features",
    slug: "real-time-data-pipeline-ml-features",
    domain: "ml",
    level: :intermediate,
    tags: ["streaming", "features", "kafka", "ml"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      EV[Operational Events<br/>Orders, Scans, Updates] --> STR[Streaming Bus<br/>Kafka/PubSub]
      STR --> FE[Feature Builder]
      FE --> FS[(Online Feature Store)]
      FE --> FD[(Offline Feature Store)]

      FS --> INF[Online Inference]
      FD --> TR[Training Jobs]
    """,
    summary: "Shows a unified pipeline where streaming events feed online and offline feature stores.",
    notes_md: """
    - Operational events flow through a streaming bus.
    - Feature builder derives features in near real-time.
    - Online store serves models for low-latency inference.
    - Offline store feeds batch training and backfills.
    """
  },
  %{
    title: "Postgres Indexing for Analytics Queries",
    slug: "postgres-indexing-analytics-queries",
    domain: "infra",
    level: :intermediate,
    tags: ["postgres", "indexing", "analytics"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      Q[Analytics Queries] --> PG[(Postgres)]

      PG --> IDX1[BTREE Indexes<br/>Primary Keys, FK Lookups]
      PG --> IDX2[GIN/GIST Indexes<br/>JSONB & Full-Text]
      PG --> PT[Partitioned Tables<br/>by Date/Tenant]

      PT --> FASTER[More predictable query times]
    """,
    summary: "Visualizes different Postgres indexing and partitioning strategies for analytics workloads.",
    notes_md: """
    - BTREE indexes are ideal for equality and range lookups on common columns.
    - GIN/GIST indexes help with JSONB and full-text search.
    - Partitioning large tables by date or tenant improves pruning and performance.
    """
  },
  %{
    title: "Event Sourcing in Logistics Workflows",
    slug: "event-sourcing-logistics",
    domain: "logistics",
    level: :advanced,
    tags: ["event-sourcing", "logistics", "cqrs"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      CMD[Command<br/>Ship Order] --> AGG[Order Aggregate]
      AGG --> EVTS[(Event Store<br/>OrderCreated, Packed, Shipped)]

      EVTS --> PRJ1[Projection<br/>Current Order State]
      EVTS --> PRJ2[Projection<br/>Shipment Timeline]
      EVTS --> PRJ3[Projection<br/>Analytics Views]
    """,
    summary: "Shows how event sourcing models logistics workflows using an event store and projections.",
    notes_md: """
    - Commands mutate aggregates which emit events.
    - Events are stored immutably in an event store.
    - Projections build read models for current state, timelines, and analytics.
    - Replay of events can rebuild projections or audit history.
    """
  },
  %{
    title: "Inventory to WMS/OMS/TMS Data Flow",
    slug: "inventory-wms-oms-tms-flow",
    domain: "logistics",
    level: :beginner,
    tags: ["wms", "oms", "tms", "inventory"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      INV[(Inventory<br/>SKU, Qty, Location)] --> WMS[WMS<br/>Warehouse Management]
      C[Customer Orders] --> OMS[OMS<br/>Order Management]

      OMS --> WMS
      WMS --> TMS[TMS<br/>Transportation Management]
      TMS --> CARR[Carriers / Shipping APIs]

      WMS --> INVUPD[Inventory Updates]
      INVUPD --> INV
    """,
    summary: "Explains how inventory, WMS, OMS, and TMS systems interact in a fulfillment flow.",
    notes_md: """
    - OMS accepts customer orders and coordinates with WMS to fulfill them.
    - WMS manages inventory, picking, packing, and updates on-hand quantities.
    - TMS handles shipment creation and communication with carriers.
    - Inventory stays in sync via continuous updates from WMS.
    """
  },
  %{
    title: "Real-Time Routing Decision Architecture",
    slug: "real-time-routing-decision-architecture",
    domain: "logistics",
    level: :advanced,
    tags: ["routing", "real-time", "logistics", "ml"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      ORD[Incoming Order] --> RS[Routing Service]

      RS --> FE[Feature Builder]
      FE --> RT[Routing Model API]
      RT --> OPTIONS[Ranked Fulfillment Options]

      OPTIONS --> POL[Policy Engine<br/>SLAs, Costs, Constraints]
      POL --> CHOICE[Selected Route]

      CHOICE --> OMS[(OMS)]
      CHOICE --> WMS[(WMS)]
    """,
    summary: "Shows how real-time routing decisions are made using ML plus business rules.",
    notes_md: """
    - Routing service builds features for an ML model based on order and network state.
    - Model proposes ranked options (warehouse, carrier, service level).
    - Policy engine applies SLAs and constraints to pick a final option.
    - OMS/WMS execute the chosen route.
    """
  },
  %{
    title: "ML Model Lifecycle: Training to Monitoring",
    slug: "ml-model-lifecycle-training-monitoring",
    domain: "ml",
    level: :beginner,
    tags: ["ml", "lifecycle", "training", "monitoring"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      DS[Data Sources] --> FE[Feature Engineering]
      FE --> TR[Training Jobs]
      TR --> REG[Model Registry]
      REG --> DEP[Deployment<br/>Online Endpoint]

      DEP --> INF[Inference Traffic]
      INF --> MON[Monitoring<br/>Metrics & Drift]
      MON -->|feedback| FE
    """,
    summary: "Outlines the lifecycle of an ML model from data to training, deployment, and monitoring.",
    notes_md: """
    - Raw data is transformed into training features.
    - Models are trained and versioned in a registry.
    - Deployed models receive live traffic and predictions are monitored.
    - Feedback loop from monitoring back to feature engineering and retraining.
    """
  },
  %{
    title: "Autoscaling Inference Services",
    slug: "autoscaling-inference-services",
    domain: "infra",
    level: :intermediate,
    tags: ["autoscaling", "k8s", "inference", "load"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      CL[Client Requests] --> LB[Load Balancer]
      LB --> POD1[Inference Pod 1]
      LB --> POD2[Inference Pod 2]
      LB --> PODN[Inference Pod N]

      POD1 --> MET[Metrics<br/>CPU, QPS, Latency]
      POD2 --> MET
      PODN --> MET

      MET --> HPA[Autoscaler]
      HPA -->|scale out/in| K8S[Kubernetes Cluster]
    """,
    summary: "Shows how inference services scale horizontally based on load and metrics.",
    notes_md: """
    - Load balancer distributes requests across pods or instances.
    - Metrics (CPU, QPS, latency) feed into an autoscaler.
    - Autoscaler adjusts replica counts in response to demand.
    - Proper scaling avoids both over-provisioning and overload.
    """
  },
  %{
    title: "Feature Store Overview for Real-Time ML",
    slug: "feature-store-overview-real-time-ml",
    domain: "ml",
    level: :intermediate,
    tags: ["feature-store", "features", "online", "offline"],
    format: :mermaid,
    diagram_source: """
    flowchart LR
      RAW[Raw Events & Batch Data] --> FB[Feature Building Jobs]
      FB --> OFS[(Offline Feature Store)]
      FB --> ONFS[(Online Feature Store)]

      OFS --> TR[Training Jobs]
      ONFS --> INF[Online Inference Services]
    """,
    summary: "Explains the role of online and offline feature stores in ML systems.",
    notes_md: """
    - Offline store holds historical features for training and backtesting.
    - Online store serves low-latency features for real-time predictions.
    - Feature building jobs write to both stores to keep them consistent.
    """
  },
  %{
    title: "LLM Tool-Calling Workflow for Logistics",
    slug: "llm-tool-calling-workflow-logistics",
    domain: "ml",
    level: :advanced,
    tags: ["llm", "tool-calling", "logistics", "agents"],
    format: :mermaid,
    diagram_source: """
    sequenceDiagram
      participant U as User / Service
      participant L as LLM
      participant T1 as Tool: GetOrderStatus
      participant T2 as Tool: GetRates

      U->>L: Natural-language request
      L-->>L: Decide tools to call

      L->>T1: tool_call(order_id)
      T1-->>L: order_status

      L->>T2: tool_call(origin, destination, dims)
      T2-->>L: rate_options

      L-->>U: Final structured response<br/>(status + best route)
    """,
    summary: "Demonstrates how an LLM orchestrates multiple tools to answer a logistics-related request.",
    notes_md: """
    - LLM interprets user intent and selects tools to call.
    - Tools encapsulate deterministic business logic and data access.
    - LLM combines tool outputs into a final answer or decision.
    - This pattern is useful for conversational logistics assistants.
    """
  },
  %{
    title: "Multi-Layer Fallback: Cache → Edge → Cloud",
    slug: "multi-layer-fallback-cache-edge-cloud",
    domain: "infra",
    level: :intermediate,
    tags: ["fallback", "cache", "edge", "cloud"],
    format: :mermaid,
    diagram_source: """
    flowchart TD
      R[Request for Prediction] --> C[(Local Cache)]
      C -->|hit| RC[Return Cached]
      C -->|miss| E[Edge Inference]

      E -->|success| RE[Return Edge Result]
      E -->|failure/unsupported| CL[Cloud Inference]

      CL -->|success| RCL[Return Cloud Result]
      CL -->|failure| FH[Fallback Heuristic / Default]
    """,
    summary: "Shows a layered fallback strategy for predictions: cache, edge, and cloud inference.",
    notes_md: """
    - Check cache first for fastest response.
    - Use edge inference when possible for low latency.
    - Cloud inference provides the most capable models when edge is insufficient.
    - Final heuristic or default protects against full-stack failure.
    """
  }
]
```
