defmodule DiagramForge.Diagrams.DiagramGeneratorTest do
  use DiagramForge.DataCase, async: true

  import Mox

  alias DiagramForge.Diagrams.DiagramGenerator
  alias DiagramForge.MockAIClient
  alias DiagramForge.Repo

  setup :verify_on_exit!

  describe "generate_for_concept/2" do
    test "successfully generates diagram from concept" do
      document = fixture(:document, raw_text: "Some technical content about GenServers.")
      concept = fixture(:concept, document: document, name: "GenServer")

      ai_response = %{
        "title" => "GenServer Message Flow",
        "domain" => "elixir",
        "tags" => ["otp", "concurrency"],
        "mermaid" => "flowchart TD\n  A[Client] --> B[GenServer]",
        "summary" => "Shows how GenServer handles messages",
        "notes_md" => "- Call\n- Cast\n- Info"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_for_concept(concept, ai_client: MockAIClient)

      assert diagram.title == "GenServer Message Flow"
      assert diagram.domain == "elixir"
      assert diagram.tags == ["otp", "concurrency"]
      assert diagram.format == :mermaid
      assert diagram.diagram_source == "flowchart TD\n  A[Client] --> B[GenServer]"
      assert diagram.summary == "Shows how GenServer handles messages"
      assert diagram.notes_md == "- Call\n- Cast\n- Info"
    end

    test "associates diagram with concept and document" do
      document = fixture(:document, raw_text: "Content")
      concept = fixture(:concept, document: document)

      ai_response = %{
        "title" => "Test Diagram",
        "domain" => "test",
        "tags" => [],
        "mermaid" => "graph TD\n  A --> B",
        "summary" => "Test summary",
        "notes_md" => "Notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_for_concept(concept, ai_client: MockAIClient)

      assert diagram.concept_id == concept.id
      assert diagram.document_id == document.id

      # Verify associations
      loaded_diagram = Repo.preload(diagram, [:concept, :document])
      assert loaded_diagram.concept.id == concept.id
      assert loaded_diagram.document.id == document.id
    end

    test "generates slug from title" do
      document = fixture(:document, raw_text: "Content")
      concept = fixture(:concept, document: document)

      ai_response = %{
        "title" => "GenServer Message Flow Diagram",
        "domain" => "elixir",
        "tags" => [],
        "mermaid" => "graph TD\n  A --> B",
        "summary" => "Summary",
        "notes_md" => "Notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_for_concept(concept, ai_client: MockAIClient)

      assert diagram.slug == "genserver-message-flow-diagram"
    end

    test "uses default values for optional fields" do
      document = fixture(:document, raw_text: "Content")
      concept = fixture(:concept, document: document)

      ai_response = %{
        "title" => "Test Diagram",
        "domain" => "test",
        "mermaid" => "graph TD\n  A --> B"
        # Missing tags, summary, notes_md
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_for_concept(concept, ai_client: MockAIClient)

      assert diagram.tags == []
      assert is_nil(diagram.summary)
      assert is_nil(diagram.notes_md)
    end

    test "builds context excerpt from document" do
      # Create document with multiple paragraphs
      paragraphs = for i <- 1..20, do: "Paragraph #{i} with some content."
      raw_text = Enum.join(paragraphs, "\n\n")
      document = fixture(:document, raw_text: raw_text)
      concept = fixture(:concept, document: document)

      ai_response = %{
        "title" => "Test Diagram",
        "domain" => "test",
        "tags" => [],
        "mermaid" => "graph TD\n  A --> B",
        "summary" => "Summary",
        "notes_md" => "Notes"
      }

      # Capture the messages sent to AI client to verify context was included
      expect(MockAIClient, :chat!, fn messages, _opts ->
        user_message = Enum.find(messages, &(&1["role"] == "user"))
        # Context should be included and truncated to first 8 paragraphs
        assert user_message["content"] =~ "Paragraph 1"
        assert user_message["content"] =~ "Paragraph 8"

        Jason.encode!(ai_response)
      end)

      assert {:ok, _diagram} =
               DiagramGenerator.generate_for_concept(concept, ai_client: MockAIClient)
    end

    test "handles document with nil raw_text" do
      document = fixture(:document, raw_text: nil)
      concept = fixture(:concept, document: document)

      ai_response = %{
        "title" => "Test Diagram",
        "domain" => "test",
        "tags" => [],
        "mermaid" => "graph TD\n  A --> B",
        "summary" => "Summary",
        "notes_md" => "Notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_for_concept(concept, ai_client: MockAIClient)

      assert diagram.title == "Test Diagram"
    end
  end

  describe "generate_from_prompt/2" do
    test "successfully generates diagram from text prompt" do
      ai_response = %{
        "title" => "Test Architecture",
        "domain" => "system-design",
        "tags" => ["architecture", "microservices"],
        "mermaid" => "graph LR\n  A[Frontend] --> B[API]\n  B --> C[Database]",
        "summary" => "High-level architecture overview",
        "notes_md" => "- Scalable\n- Modular"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_from_prompt("Create architecture diagram",
                 ai_client: MockAIClient
               )

      assert diagram.title == "Test Architecture"
      assert diagram.domain == "system-design"
      assert diagram.tags == ["architecture", "microservices"]
      assert diagram.format == :mermaid
      assert diagram.diagram_source == "graph LR\n  A[Frontend] --> B[API]\n  B --> C[Database]"
      assert diagram.summary == "High-level architecture overview"
      assert diagram.notes_md == "- Scalable\n- Modular"
    end

    test "does not associate diagram with concept or document" do
      ai_response = %{
        "title" => "Test Diagram",
        "domain" => "test",
        "tags" => [],
        "mermaid" => "graph TD\n  A --> B",
        "summary" => "Summary",
        "notes_md" => "Notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_from_prompt("Create test diagram",
                 ai_client: MockAIClient
               )

      assert is_nil(diagram.concept_id)
      assert is_nil(diagram.document_id)
    end

    test "generates slug from title" do
      ai_response = %{
        "title" => "OAuth 2.0 Flow Diagram",
        "domain" => "security",
        "tags" => [],
        "mermaid" => "sequenceDiagram\n  A->>B: Request",
        "summary" => "Summary",
        "notes_md" => "Notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_from_prompt("Create OAuth flow",
                 ai_client: MockAIClient
               )

      assert diagram.slug == "oauth-2-0-flow-diagram"
    end

    test "uses default values for optional fields" do
      ai_response = %{
        "title" => "Minimal Diagram",
        "domain" => "test",
        "mermaid" => "graph TD\n  A --> B"
        # Missing tags, summary, notes_md
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_from_prompt("Create diagram", ai_client: MockAIClient)

      assert diagram.tags == []
      assert is_nil(diagram.summary)
      assert is_nil(diagram.notes_md)
    end

    test "returns error when title is missing" do
      ai_response = %{
        "title" => nil,
        "domain" => "test",
        "tags" => [],
        "mermaid" => "graph TD\n  A --> B",
        "summary" => "Summary",
        "notes_md" => "Notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:error, changeset} =
               DiagramGenerator.generate_from_prompt("Create diagram", ai_client: MockAIClient)

      assert "can't be blank" in errors_on(changeset).title
    end
  end

  describe "slug generation" do
    test "converts title to lowercase slug" do
      document = fixture(:document, raw_text: "Content")
      concept = fixture(:concept, document: document)

      ai_response = %{
        "title" => "GenServer Supervisor Tree",
        "domain" => "elixir",
        "tags" => [],
        "mermaid" => "graph TD\n  A --> B",
        "summary" => "Summary",
        "notes_md" => "Notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_for_concept(concept, ai_client: MockAIClient)

      assert diagram.slug == "genserver-supervisor-tree"
    end

    test "replaces special characters with hyphens" do
      document = fixture(:document, raw_text: "Content")
      concept = fixture(:concept, document: document)

      ai_response = %{
        "title" => "HTTP/2 vs HTTP/1.1 Comparison!",
        "domain" => "networking",
        "tags" => [],
        "mermaid" => "graph TD\n  A --> B",
        "summary" => "Summary",
        "notes_md" => "Notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_for_concept(concept, ai_client: MockAIClient)

      assert diagram.slug == "http-2-vs-http-1-1-comparison"
    end

    test "trims leading and trailing hyphens" do
      document = fixture(:document, raw_text: "Content")
      concept = fixture(:concept, document: document)

      ai_response = %{
        "title" => "---Test Diagram---",
        "domain" => "test",
        "tags" => [],
        "mermaid" => "graph TD\n  A --> B",
        "summary" => "Summary",
        "notes_md" => "Notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert {:ok, diagram} =
               DiagramGenerator.generate_for_concept(concept, ai_client: MockAIClient)

      assert diagram.slug == "test-diagram"
    end
  end
end
