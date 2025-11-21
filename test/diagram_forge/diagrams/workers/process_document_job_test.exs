defmodule DiagramForge.Diagrams.Workers.ProcessDocumentJobTest do
  use DiagramForge.DataCase, async: true
  use Oban.Testing, repo: DiagramForge.Repo

  import Mox

  alias DiagramForge.Diagrams.{Concept, Document}
  alias DiagramForge.Diagrams.Workers.ProcessDocumentJob
  alias DiagramForge.MockAIClient
  alias DiagramForge.Repo

  setup :verify_on_exit!

  describe "perform/1" do
    test "successfully processes markdown document" do
      content = "# GenServer\n\nGenServer is an OTP behavior."
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.md")
      File.write!(path, content)

      document = fixture(:document, source_type: :markdown, path: path, status: :uploaded)

      # Mock AI response for concept extraction
      ai_response = %{
        "concepts" => [
          %{
            "name" => "GenServer",
            "short_description" => "OTP behavior",
            "category" => "elixir",
            "level" => "beginner",
            "importance" => 5
          }
        ]
      }

      stub(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert :ok =
               perform_job(ProcessDocumentJob, %{
                 "document_id" => document.id,
                 "ai_client" => "Elixir.DiagramForge.MockAIClient"
               })

      # Verify document status updated
      updated_doc = Repo.get!(Document, document.id)
      assert updated_doc.status == :ready
      assert updated_doc.raw_text == content
      assert is_nil(updated_doc.error_message)

      # Verify concepts were extracted
      concepts = Repo.all(from c in Concept, where: c.document_id == ^document.id)
      assert length(concepts) == 1
      assert hd(concepts).name == "GenServer"

      File.rm!(path)
    end

    test "handles extraction errors gracefully" do
      # Document with non-existent file
      document =
        fixture(:document, source_type: :markdown, path: "/nonexistent.md", status: :uploaded)

      # Perform the job
      assert {:error, reason} = perform_job(ProcessDocumentJob, %{"document_id" => document.id})

      assert reason =~ "Failed to read markdown file"

      # Verify document status updated to error
      updated_doc = Repo.get!(Document, document.id)
      assert updated_doc.status == :error
      assert updated_doc.error_message =~ "Failed to read markdown file"

      # Verify no concepts were created
      concepts = Repo.all(from c in Concept, where: c.document_id == ^document.id)
      assert concepts == []
    end

    test "updates existing document raw_text" do
      content = "New content"
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.md")
      File.write!(path, content)

      document =
        fixture(:document,
          source_type: :markdown,
          path: path,
          raw_text: "Old content",
          status: :uploaded
        )

      stub(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(%{"concepts" => []})
      end)

      assert :ok =
               perform_job(ProcessDocumentJob, %{
                 "document_id" => document.id,
                 "ai_client" => "Elixir.DiagramForge.MockAIClient"
               })

      updated_doc = Repo.get!(Document, document.id)
      assert updated_doc.raw_text == content
      assert updated_doc.status == :ready

      File.rm!(path)
    end

    test "handles empty document content" do
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.md")
      File.write!(path, "")

      document = fixture(:document, source_type: :markdown, path: path, status: :uploaded)

      stub(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(%{"concepts" => []})
      end)

      assert :ok =
               perform_job(ProcessDocumentJob, %{
                 "document_id" => document.id,
                 "ai_client" => "Elixir.DiagramForge.MockAIClient"
               })

      updated_doc = Repo.get!(Document, document.id)
      assert updated_doc.status == :ready
      assert updated_doc.raw_text == ""

      File.rm!(path)
    end

    test "sets status to processing at start" do
      content = "Test content"
      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.md")
      File.write!(path, content)

      document = fixture(:document, source_type: :markdown, path: path, status: :uploaded)

      # Verify initial status
      assert document.status == :uploaded

      stub(MockAIClient, :chat!, fn _messages, _opts ->
        # Verify status was updated to processing when AI is called
        doc = Repo.get!(Document, document.id)
        assert doc.status == :processing

        Jason.encode!(%{"concepts" => []})
      end)

      _result =
        perform_job(ProcessDocumentJob, %{
          "document_id" => document.id,
          "ai_client" => "Elixir.DiagramForge.MockAIClient"
        })

      # After completion, should be ready
      updated_doc = Repo.get!(Document, document.id)
      assert updated_doc.status == :ready

      File.rm!(path)
    end

    test "processes document with multiple concepts" do
      content = """
      # Elixir Concepts

      ## GenServer
      GenServer is an OTP behavior for processes.

      ## Supervisor
      Supervisor manages processes in a supervision tree.
      """

      path = Path.join(System.tmp_dir!(), "test_#{System.unique_integer([:positive])}.md")
      File.write!(path, content)

      document = fixture(:document, source_type: :markdown, path: path, status: :uploaded)

      ai_response = %{
        "concepts" => [
          %{
            "name" => "GenServer",
            "short_description" => "OTP behavior",
            "category" => "elixir",
            "level" => "intermediate",
            "importance" => 5
          },
          %{
            "name" => "Supervisor",
            "short_description" => "Process supervisor",
            "category" => "elixir",
            "level" => "intermediate",
            "importance" => 5
          }
        ]
      }

      stub(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      assert :ok =
               perform_job(ProcessDocumentJob, %{
                 "document_id" => document.id,
                 "ai_client" => "Elixir.DiagramForge.MockAIClient"
               })

      # Verify all concepts were created
      concepts =
        Repo.all(from c in Concept, where: c.document_id == ^document.id, order_by: c.name)

      assert length(concepts) == 2
      assert Enum.map(concepts, & &1.name) == ["GenServer", "Supervisor"]

      File.rm!(path)
    end
  end
end
