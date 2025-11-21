# AI Diagram Studio – Implementation Plan

## 1. Goals

Build a Phoenix LiveView app that:

1. Stores and searches **small, architecture-focused diagrams** (Mermaid).
2. Can **ingest documents** (PDF/Markdown) from your local machine, extract **concepts**, and generate diagrams for selected concepts.
3. Can **generate diagrams directly from a free-form prompt**, e.g. “Create a diagram about how tokenization works”.
4. Uses **Oban** for background work and **LLM APIs** for concept extraction and diagram generation.
5. Uses a **dark, “vibecoding-style” UI**, single-page layout.

This plan focuses on backend logic, prompts, workers, and data model; the UI can be added on top.

---

## 2. High-Level Architecture

**Core components:**

* **Schemas / Data model**

  * `Document` – uploaded PDF/Markdown reference.
  * `Concept` – extracted concept/topic within a document.
  * `Diagram` – stored diagram in Mermaid (and metadata).
* **Services**

  * `DocumentIngestor` – extract text from file, chunk it.
  * `ConceptExtractor` – call LLM to extract concepts from chunks.
  * `DiagramGenerator` – call LLM to generate Mermaid diagrams.
* **Oban workers**

  * `ProcessDocumentJob` – text extraction + concept extraction.
  * `GenerateDiagramJob` – generate diagram for one concept.
* **LLM Client**

  * `MyApp.AI.Client` – wraps OpenAI (or any) chat API.
* **LiveView**

  * `DiagramStudioLive`

    * Upload docs.
    * See extracted concepts and select them.
    * Trigger diagram generation.
    * Free-form “Generate diagram from prompt” textarea.
    * Preview diagrams (Mermaid) in dark theme.

---

## 3. Data Model

### 3.1 `Document` schema

```elixir
defmodule MyApp.Diagrams.Document do
  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :title, :string
    field :source_type, Ecto.Enum, values: [:pdf, :markdown]
    field :path, :string
    field :raw_text, :string

    field :status, Ecto.Enum,
      values: [:uploaded, :processing, :ready, :error],
      default: :uploaded

    field :error_message, :string

    has_many :concepts, MyApp.Diagrams.Concept
    has_many :diagrams, MyApp.Diagrams.Diagram

    timestamps()
  end

  def changeset(doc, attrs) do
    doc
    |> cast(attrs, [:title, :source_type, :path, :raw_text, :status, :error_message])
    |> validate_required([:title, :source_type, :path])
  end
end
```

You can store `path` as either:

* Absolute path on your dev machine, or
* Key in a storage directory / bucket that you control.

### 3.2 `Concept` schema

```elixir
defmodule MyApp.Diagrams.Concept do
  use Ecto.Schema
  import Ecto.Changeset

  schema "concepts" do
    belongs_to :document, MyApp.Diagrams.Document

    field :name, :string
    field :short_description, :string
    field :category, :string
    field :level, Ecto.Enum, values: [:beginner, :intermediate, :advanced]
    field :importance, :integer

    has_many :diagrams, MyApp.Diagrams.Diagram

    timestamps()
  end

  def changeset(concept, attrs) do
    concept
    |> cast(attrs, [:document_id, :name, :short_description, :category, :level, :importance])
    |> validate_required([:name, :category])
  end
end
```

### 3.3 `Diagram` schema

```elixir
defmodule MyApp.Diagrams.Diagram do
  use Ecto.Schema
  import Ecto.Changeset

  schema "diagrams" do
    belongs_to :concept, MyApp.Diagrams.Concept
    belongs_to :document, MyApp.Diagrams.Document

    field :slug, :string
    field :title, :string

    field :domain, :string
    field :level, Ecto.Enum, values: [:beginner, :intermediate, :advanced]

    field :tags, {:array, :string}, default: []

    field :format, Ecto.Enum, values: [:mermaid, :plantuml], default: :mermaid
    field :diagram_source, :string
    field :summary, :string
    field :notes_md, :string

    timestamps()
  end

  def changeset(diagram, attrs) do
    diagram
    |> cast(attrs, [
      :concept_id,
      :document_id,
      :slug,
      :title,
      :domain,
      :level,
      :tags,
      :format,
      :diagram_source,
      :summary,
      :notes_md
    ])
    |> validate_required([:title, :format, :diagram_source])
  end
end
```

---

## 4. LLM Integration

### 4.1 Config

In `config/runtime.exs`:

```elixir
config :my_app, MyApp.AI,
  api_key: System.get_env("OPENAI_API_KEY"),
  model: "gpt-4.1-mini"
```

### 4.2 Client module

```elixir
defmodule MyApp.AI.Client do
  @moduledoc "Thin wrapper around the chat completion API."

  @cfg Application.compile_env(:my_app, MyApp.AI)

  def chat!(messages, opts \\ []) do
    api_key = @cfg[:api_key] || raise "Missing OPENAI_API_KEY"
    model = opts[:model] || @cfg[:model]

    body = %{
      "model" => model,
      "messages" => messages,
      "response_format" => %{"type" => "json_object"}
    }

    resp =
      Req.post!("https://api.openai.com/v1/chat/completions",
        json: body,
        headers: [
          {"authorization", "Bearer #{api_key}"},
          {"content-type", "application/json"}
        ]
      )

    content =
      resp.body["choices"]
      |> List.first()
      |> get_in(["message", "content"])

    content
  end
end
```

The `chat!/2` function always returns JSON content as a string; callers decode with `Jason.decode!/1`.

---

## 5. Prompts

### 5.1 Concept extraction prompt

Used to extract concept list from a chunk of text.

**System message:**

```elixir
@concept_system_prompt """
You are a technical teaching assistant.

Given an excerpt from a technical document, identify the most important concepts that would be useful to explain visually in a diagram.

Focus on:
- architecture and components
- data flow and message flow
- lifecycles and state transitions
- interactions between services or modules

Only output strictly valid JSON. Do not include any explanation outside the JSON object.
"""
```

**User message template:**

````elixir
def concept_user_prompt(text) do
  """
  Text:
  ```text
  #{text}
````

Return JSON in this exact structure:

{
"concepts": [
{
"name": "short name for the concept",
"short_description": "1–2 sentence description suitable for learners or interview prep.",
"category": "elixir | phoenix | http | kafka | llm | agents | other",
"level": "beginner | intermediate | advanced",
"importance": 1
}
]
}

importance is an integer from 1 to 5, where 5 is most important.
Do not mention the JSON format in your response. Just output JSON.
"""
end

````

### 5.2 Diagram generation from concept

Used when generating diagrams for a specific concept (with optional context from the source doc).

**System message:**

```elixir
@diagram_system_prompt """
You generate small, interview-friendly technical diagrams in Mermaid syntax.

Constraints:
- The diagram must fit on a single screen and stay readable.
- Use at most 10 nodes and 15 edges.
- Prefer 'flowchart' or 'sequenceDiagram' unless another type is clearly better.
- Use concise labels, avoid sentences on nodes.
- Only output strictly valid JSON with the requested fields.
"""
````

**User message template:**

````elixir
def diagram_from_concept_user_prompt(concept, context_excerpt) do
  """
  Create a Mermaid diagram for this concept:

  Name: #{concept.name}
  Category: #{concept.category}
  Level: #{concept.level}
  Short description: #{concept.short_description}

  Context from the source document (optional, you may ignore irrelevant parts):
  ```text
  #{context_excerpt}
````

Return JSON like:

{
"title": "Readable title for the diagram",
"domain": "elixir | phoenix | http | kafka | llm | agents | other",
"level": "beginner | intermediate | advanced",
"tags": ["list", "of", "short", "tags"],
"mermaid": "mermaid code here (flowchart or sequenceDiagram, escaped as needed)",
"summary": "1–2 sentence explanation of what the diagram shows.",
"notes_md": "- bullet point explanation in markdown\n- keep it concise"
}

Do not include markdown fences around the mermaid code.
Do not include any explanation outside the JSON object.
"""
end

````

### 5.3 Diagram generation from free-form prompt

Used when user types “Create a diagram about how tokenization works”.

**User message template:**

```elixir
def diagram_from_prompt_user_prompt(text) do
  """
  The user wants a small technical diagram based on this description:

  "#{text}"

  Assume the reader is a curious developer preparing for interviews.

  Follow the same JSON structure as before:

  {
    "title": "...",
    "domain": "elixir | phoenix | http | kafka | llm | agents | other",
    "level": "beginner | intermediate | advanced",
    "tags": ["...", "..."],
    "mermaid": "mermaid code here",
    "summary": "...",
    "notes_md": "markdown bullets..."
  }

  Choose domain and level based on the description.
  Only output JSON.
  """
end
````

You can reuse `@diagram_system_prompt` for both concept-based and free-form prompts.

---

## 6. Chunking Strategy for Documents

Goal: handle arbitrary PDFs/Markdown (e.g. from `/Users/mkreyman/Library/CloudStorage/Dropbox/Books/Elixir/`) without blowing token limits, while still extracting good concepts.

### 6.1 Text extraction

Create `MyApp.Diagrams.DocumentIngestor` with:

```elixir
defmodule MyApp.Diagrams.DocumentIngestor do
  alias MyApp.Diagrams.Document

  def extract_text(%Document{source_type: :markdown, path: path}) do
    File.read!(path)
  end

  def extract_text(%Document{source_type: :pdf, path: path}) do
    # simplest: call a CLI like `pdftotext`
    tmp_txt = Path.join(System.tmp_dir!(), "#{Path.basename(path)}.txt")

    {_, 0} =
      System.cmd("pdftotext", ["-layout", path, tmp_txt])

    File.read!(tmp_txt)
  end
end
```

(You can later swap in a better PDF library if you prefer.)

### 6.2 Chunking

Create a simple character-based chunker with overlap, which is usually good enough for concept extraction:

```elixir
def chunk_text(text, opts \\ []) do
  chunk_size = opts[:chunk_size] || 4000
  overlap = opts[:overlap] || 500

  text
  |> String.split(~r/\n{2,}/) # paragraphs
  |> Enum.reduce({[], ""}, fn para, {chunks, current} ->
    candidate =
      if current == "" do
        para
      else
        current <> "\n\n" <> para
      end

    if String.length(candidate) >= chunk_size do
      new_chunks = [candidate | chunks]
      new_current = String.slice(candidate, -overlap, overlap) || ""
      {new_chunks, new_current}
    else
      {chunks, candidate}
    end
  end)
  |> then(fn {chunks, last} ->
    chunks =
      if String.trim(last) != "" do
        [last | chunks]
      else
        chunks
      end

    Enum.reverse(chunks)
  end)
end
```

This gives you ~3–6 chunks per chapter instead of one enormous block.

### 6.3 Concept extraction pipeline

`MyApp.Diagrams.ConceptExtractor`:

```elixir
defmodule MyApp.Diagrams.ConceptExtractor do
  alias MyApp.AI.Client
  alias MyApp.Diagrams.{Concept, Document}
  alias MyApp.Repo

  def extract_for_document(%Document{} = doc) do
    text = doc.raw_text
    chunks = MyApp.Diagrams.DocumentIngestor.chunk_text(text)

    chunks
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {chunk, idx}, acc ->
      user = concept_user_prompt(chunk)

      json =
        Client.chat!([
          %{"role" => "system", "content" => @concept_system_prompt},
          %{"role" => "user", "content" => user}
        ])
        |> Jason.decode!()

      concepts = json["concepts"] || []

      Enum.reduce(concepts, acc, fn c, acc2 ->
        key = String.downcase(c["name"] || "")

        if key == "" do
          acc2
        else
          Map.put_new(acc2, key, c)
        end
      end)
    end)
    |> Map.values()
    |> Enum.map(&insert_or_update_concept(doc, &1))
  end

  defp insert_or_update_concept(doc, attrs) do
    existing =
      Repo.get_by(Concept,
        document_id: doc.id,
        name: attrs["name"]
      )

    params = %{
      document_id: doc.id,
      name: attrs["name"],
      short_description: attrs["short_description"],
      category: attrs["category"],
      level: String.to_existing_atom(attrs["level"] || "beginner"),
      importance: attrs["importance"] || 3
    }

    (existing || %Concept{})
    |> Concept.changeset(params)
    |> Repo.insert_or_update!()
  end
end
```

This:

* Iterates over chunks.
* Calls LLM per chunk.
* Deduplicates concepts by downcased `name`.

---

## 7. Oban Workers

### 7.1 `ProcessDocumentJob`

Purpose: for a newly uploaded `Document`:

* Extract `raw_text`.
* Run concept extraction.

```elixir
defmodule MyApp.Diagrams.Workers.ProcessDocumentJob do
  use Oban.Worker, queue: :documents

  alias MyApp.Diagrams.{Document, DocumentIngestor, ConceptExtractor}
  alias MyApp.Repo

  @impl true
  def perform(%Oban.Job{args: %{"document_id" => doc_id}}) do
    doc = Repo.get!(Document, doc_id)

    doc
    |> Document.changeset(%{status: :processing})
    |> Repo.update!()

    text = DocumentIngestor.extract_text(doc)

    doc =
      doc
      |> Document.changeset(%{raw_text: text})
      |> Repo.update!()

    ConceptExtractor.extract_for_document(doc)

    doc
    |> Document.changeset(%{status: :ready})
    |> Repo.update!()

    :ok
  rescue
    e ->
      doc = Repo.get(Document, doc_id)

      if doc do
        doc
        |> Document.changeset(%{status: :error, error_message: Exception.message(e)})
        |> Repo.update()
      end

      :error
  end
end
```

You enqueue this after a document upload:

```elixir
Oban.insert!(MyApp.Diagrams.Workers.ProcessDocumentJob.new(%{"document_id" => doc.id}))
```

### 7.2 `GenerateDiagramJob`

Purpose: generate a diagram for a single concept. This can be triggered from the UI (checkbox selection).

```elixir
defmodule MyApp.Diagrams.Workers.GenerateDiagramJob do
  use Oban.Worker, queue: :diagrams

  alias MyApp.Diagrams.{Concept, Diagram, Document}
  alias MyApp.AI.Client
  alias MyApp.Repo

  @impl true
  def perform(%Oban.Job{args: %{"concept_id" => concept_id}}) do
    concept =
      Concept
      |> Repo.get!(concept_id)
      |> Repo.preload(:document)

    context_excerpt =
      build_context_excerpt(concept.document)

    user_prompt = diagram_from_concept_user_prompt(concept, context_excerpt)

    json =
      Client.chat!([
        %{"role" => "system", "content" => @diagram_system_prompt},
        %{"role" => "user", "content" => user_prompt}
      ])
      |> Jason.decode!()

    attrs = %{
      concept_id: concept.id,
      document_id: concept.document_id,
      title: json["title"],
      slug: slugify(json["title"]),
      domain: json["domain"],
      level: String.to_existing_atom(json["level"] || "beginner"),
      tags: json["tags"] || [],
      format: :mermaid,
      diagram_source: json["mermaid"],
      summary: json["summary"],
      notes_md: json["notes_md"]
    }

    %Diagram{}
    |> Diagram.changeset(attrs)
    |> Repo.insert!()

    :ok
  end

  defp build_context_excerpt(%Document{raw_text: text}) do
    text
    |> String.split(~r/\n{2,}/)
    |> Enum.take(8)
    |> Enum.join("\n\n")
    |> String.slice(0, 3000)
  end

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end
end
```

### 7.3 Free-form prompt diagrams (optional Oban)

You can either:

* Generate immediately in the LiveView (synchronous LLM call), or
* Use Oban if you want it to be non-blocking.

Synchronous example in a LiveView action:

```elixir
def generate_diagram_from_prompt(text) do
  user_prompt = diagram_from_prompt_user_prompt(text)

  json =
    MyApp.AI.Client.chat!([
      %{"role" => "system", "content" => @diagram_system_prompt},
      %{"role" => "user", "content" => user_prompt}
    ])
    |> Jason.decode!()

  attrs = %{
    title: json["title"],
    slug: slugify(json["title"]),
    domain: json["domain"],
    level: String.to_existing_atom(json["level"] || "beginner"),
    tags: json["tags"] || [],
    format: :mermaid,
    diagram_source: json["mermaid"],
    summary: json["summary"],
    notes_md: json["notes_md"]
  }

  %MyApp.Diagrams.Diagram{}
  |> MyApp.Diagrams.Diagram.changeset(attrs)
  |> MyApp.Repo.insert!()
end
```

---

## 8. LiveView UX (brief)

Single page `DiagramStudioLive`:

* **Left column: Documents**

  * Upload widget.
  * List of documents with status badges (`Uploaded`, `Processing`, `Ready`, `Error`).
  * Clicking a document loads its concepts.

* **Middle column: Concepts**

  * List of concepts for selected document.
  * Checkboxes to select concepts.
  * Button: “Generate diagrams for selected concepts” (enqueues `GenerateDiagramJob` per concept).
  * Shows whether a concept already has a diagram.

* **Right column: Diagram + Free-form**

  * Dropdown or list of diagrams for the selected concept.
  * `Mermaid` `<pre>` block for preview.
  * Summary + notes in markdown.
  * Below that: a textarea + button:

    * “Generate diagram from prompt” → calls `generate_diagram_from_prompt/1` and shows the result.

Dark theme using Tailwind, e.g.:

* `bg-slate-950 text-slate-100`
* Accent borders `border-slate-800`
* Cards: `bg-slate-900 rounded-xl p-4`

Mermaid integration via a LiveView hook as described earlier.

---

## 9. How to Point Your Agent

Concrete tasks for your local coding agent:

1. **Data & migrations**

   * Create `documents`, `concepts`, `diagrams` tables and schemas exactly as described.
   * Add indexes on `concepts(document_id, name)` and `diagrams(slug)`.

2. **AI integration**

   * Implement `MyApp.AI.Client.chat!/2` using OpenAI (or compatible).
   * Implement prompt functions and constants from section 5 in a dedicated module, e.g. `MyApp.AI.Prompts`.

3. **Document ingestion + chunking**

   * Implement `MyApp.Diagrams.DocumentIngestor.extract_text/1` and `chunk_text/2`.
   * Ensure PDFs and Markdown from your local path can be selected and uploaded via the browser.

4. **Concept extraction**

   * Implement `MyApp.Diagrams.ConceptExtractor.extract_for_document/1` using the LLM prompts and chunking strategy.

5. **Oban workers**

   * Implement `ProcessDocumentJob` and `GenerateDiagramJob` as in section 7.
   * Wire them into application supervision tree and ensure queues exist.

6. **Free-form diagram generation**

   * Implement `generate_diagram_from_prompt/1` service function and expose it from the LiveView.

7. **LiveView**

   * Implement `DiagramStudioLive` with three-column layout, dark theme, file upload, concept listing, diagram preview, and prompt-based diagram generation.

8. **Mermaid rendering**

   * Add Mermaid.js to `app.js` and a LiveView hook to run `mermaid.run` on updates.

Once these are done, you’ll have:

* Upload PDFs/Markdown from your `/Books/Elixir` folder.
* Get extracted concepts as a list.
* Select concepts → generate and store diagrams.
* Type/paste prompts like “Create a diagram about how tokenization works” and persist those diagrams too.

If you want, next step I can do is: write a concrete `DiagramStudioLive` skeleton (module + template) so the agent only needs to fill in the wiring.

---

## 10. Production Enhancements

The following enhancements have been implemented to improve reliability, observability, and user experience in production:

### 10.1 Error Handling & Retry Logic

**Automatic Retry with Exponential Backoff**

The AI client includes robust retry logic for handling transient failures:

```elixir
# DiagramForge.ErrorHandling.Retry
Retry.with_retry(
  fn -> make_api_request() end,
  max_attempts: 3,
  base_delay_ms: 1000,
  max_delay_ms: 10_000,
  context: %{operation: "openai_chat_completion"}
)
```

**Features:**
- Exponential backoff: 1s → 2s → 4s → 8s (configurable)
- Smart error categorization via `ErrorCategorizer`:
  - **Transient** (503, 504, 502): Retryable
  - **Rate limit** (429): Retryable with backoff
  - **Authentication** (401, 403): Not retryable, critical
  - **Configuration**: Missing API keys - not retryable
  - **Permanent** (400, 404, 422): Not retryable
  - **Network**: Connection errors - retryable
- Only retries errors identified as retryable
- Logs each retry attempt with context

**Error Categorization:**

```elixir
# DiagramForge.ErrorHandling.ErrorCategorizer
{category, severity} = ErrorCategorizer.categorize_error(error)
# Returns: {:transient, :medium} | {:rate_limit, :high} | {:authentication, :critical} | etc.
```

### 10.2 Telemetry & Monitoring

**Retry Metrics**

Comprehensive telemetry events for monitoring retry behavior:

```elixir
# Events emitted:
[:diagram_forge, :retry, :start]      # When retry logic begins
[:diagram_forge, :retry, :attempt]    # On each retry attempt
[:diagram_forge, :retry, :success]    # When operation succeeds
[:diagram_forge, :retry, :failure]    # When all retries exhausted
```

**Measurements & Metadata:**

```elixir
# Start event
%{system_time: System.system_time()}
%{max_attempts: 3, context: %{operation: "..."}}

# Attempt event
%{attempt: 2, delay_ms: 2000}
%{error: error, category: :transient, severity: :medium, context: %{...}}

# Success event
%{attempts_used: 2, duration: 3500}
%{context: %{...}}

# Failure event
%{attempts_used: 3, duration: 8000}
%{error: error, context: %{...}}
```

These events can be consumed by telemetry handlers for metrics dashboards, alerting, and performance monitoring.

### 10.3 Rate Limit Monitoring

**OpenAI Rate Limit Header Parsing**

The AI client automatically parses and monitors rate limit headers from OpenAI responses:

```elixir
# Headers parsed:
- x-ratelimit-limit-requests
- x-ratelimit-remaining-requests
- x-ratelimit-reset-requests
- x-ratelimit-limit-tokens
- x-ratelimit-remaining-tokens
- x-ratelimit-reset-tokens
```

**Automatic Warnings:**

```elixir
# Critical warning (< 10% remaining)
Logger.warning("OpenAI rate limit critical: requests - 25/500 (5.0%), reset: 120s")

# Approaching limit (< 25% remaining)
Logger.warning("OpenAI rate limit approaching: requests - 100/500 (20.0%), reset: 60s")

# Status (> 25% remaining)
Logger.debug("OpenAI rate limit status: requests - 450/500 (90.0%)")
```

This proactive monitoring helps prevent unexpected rate limit errors by providing visibility into API usage before limits are exceeded.

### 10.4 Real-time Progress Tracking

**Background Job Progress via PubSub**

Diagram generation jobs broadcast real-time progress events:

```elixir
# DiagramForge.Diagrams.Workers.GenerateDiagramJob broadcasts:
{:generation_started, concept_id}
{:generation_completed, concept_id, diagram_id}
{:generation_failed, concept_id, reason, category, severity}
```

**LiveView Integration:**

The LiveView subscribes to progress events and displays:
- Real-time progress bar: "Generating 2 of 5 diagrams..."
- Automatic diagram list refresh on completion
- Error notifications with severity information

```elixir
# In DiagramStudioLive
Phoenix.PubSub.subscribe(DiagramForge.PubSub, "diagram_generation:#{document_id}")

def handle_info({:generation_completed, concept_id, diagram_id}, socket) do
  # Update progress, refresh diagrams list
end
```

### 10.5 Error Severity Badges in UI

**Visual Error Feedback**

Failed diagram generations display color-coded severity badges:

- 🔴 **CRITICAL** (red): Authentication failures requiring admin attention
- 🟠 **HIGH** (orange): Rate limits and severe server errors
- 🟡 **MEDIUM** (yellow): Transient failures and bad requests
- 🔵 **LOW** (blue): Permanent low-impact errors (404s)

```elixir
# Error details stored per concept
%{
  reason: %{status: 429},
  category: :rate_limit,
  severity: :high
}
```

Badges are automatically cleared when:
- Starting new generation attempts
- Switching to a different document

This provides immediate visual feedback on error severity, helping users prioritize which failures need immediate attention versus those that can be safely retried.

### 10.6 Testing Infrastructure

**Comprehensive Test Coverage**

All production enhancements include full test coverage:

**HTTP Mocking with Bypass:**
```elixir
# test/diagram_forge/ai/client_test.exs
setup do
  bypass = Bypass.open()
  %{bypass: bypass, base_url: "http://localhost:#{bypass.port}"}
end

Bypass.expect_once(bypass, "POST", "/chat/completions", fn conn ->
  # Mock OpenAI responses
end)
```

**Test Coverage:**
- 15 tests for AI client behavior (retries, errors, rate limits)
- 6 tests for telemetry event emissions
- 5 tests for rate limit header parsing
- 6 tests for error severity badge display
- 5 tests for real-time progress tracking

**Total: 157 tests, all passing**

### 10.7 Quality Gates

All code passes strict quality checks:

```bash
mix precommit
```

Runs:
- **Credo**: Static code analysis (0 issues)
- **Dialyzer**: Type checking (7 known issues in .dialyzer_ignore.exs)
- **Mix Format**: Code formatting (enforced)
- **ExUnit**: Full test suite (157 tests, 0 failures)

Git pre-commit hooks enforce quality standards - commits are blocked without passing all checks.
