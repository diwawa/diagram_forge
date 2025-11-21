1. **OpenAI API configuration**

   * Yes, I have `OPENAI_API_KEY` set in env.
   * Default model: **`gpt-4.1-mini`**.
   * Put this in `config/runtime.exs` under `:diagram_forge, DiagramForge.AI` (or similar).

2. **Database**

   * Use **PostgreSQL (default)**.
   * Standard local config is fine (e.g. `diagram_forge_dev` DB).
   * No special AlloyDB stuff for now.

3. **Implementation priority**

   * Start with **data model + migrations**, then **services & Oban workers**, *then* LiveView.
   * For the UI:

     * Build a skeleton LiveView that uses **real DB records** as soon as models exist (no big mock-data layer needed).

4. **PDF processing**

   * You can assume `pdftotext` is installed.
   * Still:

     * If `pdftotext` fails (non-zero exit), set `Document.status = :error` with `error_message`.

5. **Oban**

   * Yes, **add Oban now**.
   * Use at least two queues: `:documents`, `:diagrams` as we discussed.
   * We will design everything around async processing from the beginning.

6. **Document storage**

   * Implement **file upload via the web UI** and copy uploaded files into a local project directory (e.g. `priv/uploads/documents` or `uploads/documents`).
   * Store **relative paths** in the DB (not absolute Dropbox paths).
   * Later, we can add a dev-only helper to import files from `/Users/mkreyman/...` if needed, but not as the main path.

---

## 3. Logic TODO list for your agent

Here’s a clean ordered backlog to keep it on rails.

### Phase 1 – Dependencies & config

1. Add **Oban** dependency and basic config:

   * Queues: `documents`, `diagrams`.
   * Add Oban supervision to `application.ex`.

2. Add **AI config**:

   * `config/runtime.exs`:

     * Read `OPENAI_API_KEY` from env.
     * Set default model to `"gpt-4.1-mini"`.

3. Add **Req** (if not already there) for HTTP and verify a simple `mix test` passes.

---

### Phase 2 – Data model & migrations

Create migrations + schemas for:

1. **`documents`**

   * Fields: `title`, `source_type` (`:pdf | :markdown`), `path`, `raw_text`, `status` (`:uploaded | :processing | :ready | :error`), `error_message`.
   * Associations: `has_many :concepts`, `has_many :diagrams`.

2. **`concepts`**

   * Fields: `name`, `short_description`, `category`, `level` (`:beginner | :intermediate | :advanced`), `importance` (int).
   * Assoc: `belongs_to :document`, `has_many :diagrams`.

3. **`diagrams`**

   * Fields: `slug`, `title`, `domain`, `level` enum, `tags` (array), `format` enum (default `:mermaid`), `diagram_source`, `summary`, `notes_md`.
   * Assoc: `belongs_to :concept`, `belongs_to :document`.

4. Add sensible indexes:

   * `concepts(document_id, name)`
   * `diagrams(slug)`
   * `documents(status)`

Run migrations and ensure `mix test` is still green.

---

### Phase 3 – AI client & prompts

1. Implement `DiagramForge.AI.Client` (or similar):

   * Function `chat!(messages, opts \\ [])` that:

     * Uses `Req.post!/3` to call OpenAI `/v1/chat/completions`.
     * Sets `model` from config or `opts`.
     * Uses `response_format: %{type: "json_object"}`.
     * Returns `message["content"]` as a JSON string.

2. Implement prompts module `DiagramForge.AI.Prompts`:

   * `concept_system_prompt/0`
   * `concept_user_prompt(text)`
   * `diagram_system_prompt/0`
   * `diagram_from_concept_user_prompt(concept, context_excerpt)`
   * `diagram_from_prompt_user_prompt(text)`

You can base them directly on the versions we wrote earlier.

---

### Phase 4 – Document ingestion & chunking

1. Create `DiagramForge.Diagrams.DocumentIngestor`:

   * `extract_text(%Document{source_type: :markdown})` → `File.read!`.
   * `extract_text(%Document{source_type: :pdf})` → call `pdftotext` CLI, read temp file, handle non-zero exit as error.

2. Implement `chunk_text/2`:

   * Default `chunk_size: 4000`, `overlap: 500`.
   * Paragraph-based splitting with overlap as we outlined.

3. Add simple unit tests for chunking and PDF extraction behavior (including error path).

---

### Phase 5 – Concept extraction service + job

1. Implement `DiagramForge.Diagrams.ConceptExtractor`:

   * `extract_for_document(%Document{})`:

     * Use `doc.raw_text`.
     * Chunk via `DocumentIngestor.chunk_text/1`.
     * For each chunk:

       * Build system + user messages.
       * Call `AI.Client.chat!/2`.
       * Decode JSON.
       * Deduplicate concepts by lowercased `name`.
     * Insert or update `Concept` records (per `document_id + name`).

2. Implement `DiagramForge.Diagrams.Workers.ProcessDocumentJob` (Oban):

   * `perform/1`:

     * Set `Document.status = :processing`.
     * Call `DocumentIngestor.extract_text/1`, update `raw_text`.
     * Call `ConceptExtractor.extract_for_document/1`.
     * On success → `status = :ready`.
     * On error → `status = :error`, set `error_message`.

3. Add a helper in a context module, e.g. `DiagramForge.Diagrams.upload_document/1`, that:

   * Inserts a `Document` row.
   * Enqueues `ProcessDocumentJob`.

---

### Phase 6 – Diagram generation service + job

1. Implement a `DiagramForge.Diagrams.DiagramGenerator` module:

   * `generate_for_concept(concept)`:

     * Preload its document.
     * Build context excerpt (e.g., first N paragraphs from `raw_text`, limited length).
     * Call `AI.Client.chat!` with diagram prompts.
     * Insert new `Diagram` record.

   * `generate_from_prompt(text)`:

     * Call `AI.Client.chat!` with free-form prompt.
     * Insert a `Diagram` with no `concept_id`/`document_id` (or optional).

2. Implement `DiagramForge.Diagrams.Workers.GenerateDiagramJob`:

   * Takes `concept_id`.
   * Calls `DiagramGenerator.generate_for_concept/1`.

---

### Phase 7 – LiveView skeleton (with real DB)

1. Create `DiagramForgeWeb.DiagramStudioLive`:

   * Route: `/studio` or `/diagrams`.
   * On mount:

     * Load list of `documents` with status.
   * UI layout: 3 columns, dark theme placeholders:

     * Left: documents.
     * Middle: concepts (for selected doc).
     * Right: diagram preview + prompt box.

2. Implement:

   * Upload form:

     * Store uploaded file into `uploads/documents`.
     * Call context function to create `Document` + enqueue `ProcessDocumentJob`.
   * Click handlers:

     * Select document → load its concepts + which have diagrams.
     * Select concept → load its diagrams (for now, the latest / only).

3. For now, you can:

   * Just render `diagram.diagram_source` in a `<pre>` without Mermaid – hook comes later.

---

### Phase 8 – Mermaid integration & free-form diagrams

1. Add Mermaid.js to `app.js`:

   * Initialize with `startOnLoad: false`, `theme: "dark"`.

2. Add LiveView hook `Mermaid`:

   * On `mounted/updated`, run `mermaid.run({ querySelector: ".mermaid" })`.

3. Update preview area to:

   * Wrap diagram source in `<pre class="mermaid">`.
   * Place hook on the container.

4. Add free-form prompt box:

   * Textarea + button `Generate`.
   * On click:

     * Call `DiagramGenerator.generate_from_prompt/1`.
     * Show the resulting diagram in the right pane.

---

### Phase 9 – UX polish & safety ✅

1. ✅ Show status badges for documents (`Uploaded`, `Processing`, `Ready`, `Error`).
2. ✅ Show error messages if `Document.status = :error`.
3. ✅ Show small progress indicator when diagrams are being generated.
4. ✅ Add basic rate limiting/backoff in AI client (optional but nice).

**Status: COMPLETED**

---

### Phase 10 – Production Enhancements ✅

**Error Handling & Retry Logic:**

1. ✅ Implement automatic retry with exponential backoff for OpenAI API calls
   - Retry logic: 1s → 2s → 4s → 8s (configurable)
   - Smart error categorization (transient, rate_limit, authentication, permanent, network)
   - Only retries errors identified as retryable
   - Comprehensive logging with context

2. ✅ Error categorization system
   - Transient errors (503, 504, 502) → retryable
   - Rate limits (429) → retryable with backoff
   - Authentication (401, 403) → not retryable, critical severity
   - Permanent errors (400, 404, 422) → not retryable
   - Network errors (connection refused, DNS) → retryable

**Telemetry & Monitoring:**

3. ✅ Add comprehensive telemetry instrumentation
   - Retry lifecycle events: start, attempt, success, failure
   - Measurements: attempts_used, duration, delay_ms
   - Metadata: error details, category, severity, context
   - Full test coverage (6 tests for telemetry events)

4. ✅ OpenAI rate limit header parsing and monitoring
   - Parse x-ratelimit-* headers for requests and tokens
   - Automatic warnings at different thresholds:
     - Critical: < 10% remaining
     - Approaching: < 25% remaining
     - Status: > 25% remaining (debug level)
   - Include reset time information in warnings
   - Full test coverage (5 tests for rate limit scenarios)

**Real-time User Experience:**

5. ✅ Background job progress tracking via PubSub
   - Broadcast generation_started, generation_completed, generation_failed events
   - Real-time progress bar: "Generating X of Y diagrams..."
   - Automatic diagram list refresh on completion
   - Full test coverage (5 tests for progress tracking)

6. ✅ Error severity badges in UI
   - Color-coded visual feedback:
     - 🔴 CRITICAL (red): Authentication failures
     - 🟠 HIGH (orange): Rate limits
     - 🟡 MEDIUM (yellow): Transient failures
     - 🔵 LOW (blue): Permanent low-impact errors
   - Automatic badge clearing on regeneration
   - Full test coverage (6 tests for all severity levels)

**Testing Infrastructure:**

7. ✅ Comprehensive test coverage for all enhancements
   - HTTP mocking with Bypass for AI client testing
   - 15 tests for AI client behavior (retries, errors, rate limits)
   - 6 tests for telemetry event emissions
   - 5 tests for rate limit header parsing
   - 6 tests for error severity badge display
   - 5 tests for real-time progress tracking
   - **Total: 157 tests, all passing**

8. ✅ Quality gates enforcement
   - Credo: Static code analysis (0 issues)
   - Dialyzer: Type checking (7 known issues in .dialyzer_ignore.exs)
   - Mix Format: Code formatting enforced
   - Pre-commit hooks block commits without passing all checks

**Status: COMPLETED**

All production enhancements have been implemented with comprehensive test coverage and documentation.

