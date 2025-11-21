Concepts seed list


```elixir
concepts = [
  %{
    name: "GenServer call vs cast",
    short_description: "How synchronous call and asynchronous cast interact with a GenServer and their trade-offs.",
    category: "elixir",
    level: :intermediate,
    importance: 5
  },
  %{
    name: "OTP supervision tree basics",
    short_description: "How supervisors organize workers into trees and apply different restart strategies.",
    category: "elixir",
    level: :intermediate,
    importance: 5
  },
  %{
    name: "Fault tolerance with Elixir processes",
    short_description: "Letting processes crash and using supervisors to restart them for fault isolation.",
    category: "elixir",
    level: :intermediate,
    importance: 5
  },
  %{
    name: "Kafka and Broadway event-driven processing",
    short_description: "Using Kafka topics and Broadway pipelines to process streams of events in Elixir.",
    category: "elixir",
    level: :intermediate,
    importance: 5
  },
  %{
    name: "Prediction-serving API with fallback logic",
    short_description: "Designing a prediction API with cache, cloud ML calls, and local fallback behavior.",
    category: "ml",
    level: :advanced,
    importance: 5
  },
  %{
    name: "Cloud ML inference with Vertex AI",
    short_description: "Calling a managed Vertex AI endpoint from an Elixir service using feature data.",
    category: "ml",
    level: :intermediate,
    importance: 4
  },
  %{
    name: "Edge vs cloud inference architecture",
    short_description: "Balancing latency, accuracy, and cost between edge inference and cloud inference.",
    category: "ml",
    level: :intermediate,
    importance: 4
  },
  %{
    name: "Demand forecasting API architecture",
    short_description: "Integrating forecasting models with order and inventory data via an API.",
    category: "operations",
    level: :intermediate,
    importance: 5
  },
  %{
    name: "Intelligent routing ML pipeline",
    short_description: "Using ML to generate and rank routing options for operational decisions.",
    category: "operations",
    level: :advanced,
    importance: 5
  },
  %{
    name: "Supply chain anomaly detection loop",
    short_description: "Streaming operational events into an anomaly detector and alerting ops teams.",
    category: "operations",
    level: :intermediate,
    importance: 4
  },
  %{
    name: "Caching ML predictions with ETS and Redis",
    short_description: "A two-level cache using ETS and Redis to reduce repeated ML calls.",
    category: "elixir",
    level: :intermediate,
    importance: 5
  },
  %{
    name: "Rate limiting LLM API requests",
    short_description: "Using a gateway and rate limiter to protect external LLM providers and enforce quotas.",
    category: "infra",
    level: :intermediate,
    importance: 4
  },
  %{
    name: "Semantic search with embeddings and vector DB",
    short_description: "Generating embeddings and using a vector database to find semantically similar items.",
    category: "ml",
    level: :intermediate,
    importance: 5
  },
  %{
    name: "Observability pipeline for ML-powered services",
    short_description: "Collecting logs, metrics, and traces from services into observability backends.",
    category: "infra",
    level: :intermediate,
    importance: 4
  },
  %{
    name: "Circuit breaker and retry around ML calls",
    short_description: "Protecting services that call ML endpoints using retries and circuit breakers.",
    category: "infra",
    level: :intermediate,
    importance: 4
  },
  %{
    name: "Real-time data pipeline feeding ML features",
    short_description: "Streaming operational events into feature stores for online and offline ML.",
    category: "ml",
    level: :intermediate,
    importance: 5
  },
  %{
    name: "Postgres indexing for analytics queries",
    short_description: "Using BTREE, GIN/GIST indexes and partitioning to speed up analytics workloads.",
    category: "infra",
    level: :intermediate,
    importance: 4
  },
  %{
    name: "Event sourcing in operational workflows",
    short_description: "Modeling business processes as event streams with projections for read models.",
    category: "operations",
    level: :advanced,
    importance: 4
  },
  %{
    name: "Inventory and WMS/OMS/TMS data flow",
    short_description: "How inventory, order management, warehouse, and transportation systems interact.",
    category: "operations",
    level: :beginner,
    importance: 4
  },
  %{
    name: "Real-time routing decision architecture",
    short_description: "Combining ML routing models with a policy engine for real-time route selection.",
    category: "operations",
    level: :advanced,
    importance: 5
  },
  %{
    name: "ML model lifecycle from training to monitoring",
    short_description: "The end-to-end lifecycle of an ML model: data, training, deployment, and monitoring.",
    category: "ml",
    level: :beginner,
    importance: 4
  },
  %{
    name: "Autoscaling inference services",
    short_description: "Scaling inference services horizontally based on load and performance metrics.",
    category: "infra",
    level: :intermediate,
    importance: 4
  },
  %{
    name: "Feature store for real-time ML",
    short_description: "Using online and offline feature stores to support training and low-latency inference.",
    category: "ml",
    level: :intermediate,
    importance: 5
  },
  %{
    name: "LLM tool-calling workflow for operations",
    short_description: "Using an LLM to orchestrate calls to operational tools like order status and rate lookup.",
    category: "ml",
    level: :advanced,
    importance: 4
  },
  %{
    name: "Multi-layer fallback: cache, edge, cloud",
    short_description: "A layered fallback strategy from cache to edge inference to cloud inference.",
    category: "infra",
    level: :intermediate,
    importance: 4
  }
]

# Example insert (adapt module names as needed):
# Enum.each(concepts, fn attrs ->
#   %DiagramForge.Diagrams.Concept{}
#   |> DiagramForge.Diagrams.Concept.changeset(attrs)
#   |> DiagramForge.Repo.insert!()
# end)
```

