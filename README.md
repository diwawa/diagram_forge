# DiagramForge

AI-powered diagram generation from technical documents. DiagramForge uses LLMs to extract key concepts from your documentation and automatically generate visual diagrams in Mermaid format.

## Features

- **Document Processing**: Upload PDF or Markdown files for analysis
- **AI Concept Extraction**: Automatically identifies important technical concepts worth visualizing
- **Diagram Generation**: Creates Mermaid diagrams (flowcharts, sequence diagrams, etc.) with explanatory notes
- **Background Processing**: Asynchronous job processing with Oban for scalable document analysis
- **Comprehensive Test Suite**: 75 tests with Mox for reliable behavior without external API dependencies

## Tech Stack

- **Phoenix 1.8**: Web framework with LiveView
- **Elixir 1.18**: Functional programming language on the BEAM
- **PostgreSQL**: Database with Ecto for data persistence
- **Oban**: Background job processing
- **OpenAI API**: LLM integration for concept extraction and diagram generation
- **Mermaid**: Diagram syntax for visualizations

## Getting Started

### Prerequisites

- Elixir 1.18+
- PostgreSQL 14+
- OpenAI API key

### Installation

1. Clone the repository
2. Install dependencies:
   ```bash
   mix deps.get
   ```

3. Set up your database:
   ```bash
   mix ecto.setup
   ```

4. Configure your OpenAI API key in `config/dev.exs` or set the `OPENAI_API_KEY` environment variable

5. Start the Phoenix server:
   ```bash
   mix phx.server
   ```

Visit [`localhost:4000`](http://localhost:4000) in your browser.

## Usage

1. **Upload a Document**: Submit a PDF or Markdown file containing technical content
2. **Processing**: DiagramForge extracts text and identifies key concepts using AI
3. **View Diagrams**: Browse generated diagrams with explanations and source context

## Development

### Running Tests

```bash
mix test
```

All tests use Mox for mocking external dependencies (no API keys needed for testing).

### Code Quality

Run all quality checks:

```bash
mix precommit
```

This runs:
- Compilation with warnings as errors
- Code formatting
- Credo (static analysis)
- Dialyzer (type checking)
- Full test suite

### Project Structure

- `lib/diagram_forge/diagrams/` - Core domain logic
  - `document_ingestor.ex` - Text extraction and chunking
  - `concept_extractor.ex` - AI-powered concept identification
  - `diagram_generator.ex` - Mermaid diagram generation
  - `workers/` - Oban background jobs
- `lib/diagram_forge/ai/` - LLM integration
- `test/` - Comprehensive test coverage with fixtures and mocks

## Configuration

### AI Client

By default, DiagramForge uses OpenAI's GPT-4.1-mini model. You can configure this in `config/config.exs`:

```elixir
config :diagram_forge,
  ai_model: "gpt-4.1-mini"
```

### Oban Queues

Background job processing is configured with two queues:
- `documents` (concurrency: 5) - Document text extraction and concept analysis
- `diagrams` (concurrency: 10) - Diagram generation from concepts

## Contributing

1. Fork the repository
2. Create a feature branch
3. Write tests for your changes
4. Ensure `mix precommit` passes
5. Submit a pull request

## License

This project is open source and available under the MIT License.
