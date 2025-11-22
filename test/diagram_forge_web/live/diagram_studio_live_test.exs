defmodule DiagramForgeWeb.DiagramStudioLiveTest do
  use DiagramForgeWeb.ConnCase
  use Oban.Testing, repo: DiagramForge.Repo

  import Phoenix.LiveViewTest
  import Mox

  alias DiagramForge.Diagrams
  alias DiagramForge.MockAIClient

  setup :verify_on_exit!

  describe "mount" do
    test "initializes with empty state", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert view
             |> element("#upload-form")
             |> has_element?()

      assert has_element?(view, "h1", "DiagramForge Studio")
    end

    test "loads existing documents", %{conn: conn} do
      document = fixture(:document)

      {:ok, view, html} = live(conn, ~p"/")

      assert html =~ document.title
      assert has_element?(view, "[phx-value-id='#{document.id}']")
    end
  end

  describe "select_document" do
    test "loads concepts and diagrams for selected document", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)
      diagram = fixture(:diagram, document_id: document.id, concept_id: concept.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Select the document
      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      html = render(view)

      # Verify concepts are loaded
      assert html =~ concept.name

      # Expand the concept to see diagrams
      view
      |> expand_concept(concept.id)

      html = render(view)

      # Verify diagrams are loaded
      assert html =~ diagram.title
    end

    test "clears selected concepts when switching documents", %{conn: conn} do
      doc1 = fixture(:document, title: "Doc 1")
      doc2 = fixture(:document, title: "Doc 2")
      concept1 = fixture(:concept, document_id: doc1.id)
      _concept2 = fixture(:concept, document_id: doc2.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Select first document and toggle a concept
      view
      |> element("[phx-value-id='#{doc1.id}']")
      |> render_click()

      view
      |> expand_concept(concept1.id)
      |> element("input[phx-value-id='#{concept1.id}']")
      |> render_click()

      # Verify concept is selected
      assert view
             |> element("input[phx-value-id='#{concept1.id}'][checked]")
             |> has_element?()

      # Switch to second document
      view
      |> element("[phx-value-id='#{doc2.id}']")
      |> render_click()

      # Verify selected concepts were cleared
      refute view
             |> element("input[checked]")
             |> has_element?()
    end
  end

  describe "toggle_concept" do
    test "adds concept to selection", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      # Toggle concept on
      view
      |> expand_concept(concept.id)
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      # Verify checkbox is checked
      assert view
             |> element("input[phx-value-id='#{concept.id}'][checked]")
             |> has_element?()

      # Verify generate button shows count
      assert has_element?(view, "button", "Generate (1)")
    end

    test "removes concept from selection when toggled again", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      # Toggle on
      view
      |> expand_concept(concept.id)
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      # Toggle off
      view
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      # Verify checkbox is unchecked
      refute view
             |> element("input[phx-value-id='#{concept.id}'][checked]")
             |> has_element?()

      # Verify generate button with count is gone (button exists but not with count)
      refute has_element?(view, "button", ~r/Generate \(\d+\)/)
    end

    test "supports multiple concept selection", %{conn: conn} do
      document = fixture(:document)
      concept1 = fixture(:concept, document_id: document.id, name: "Concept 1")
      concept2 = fixture(:concept, document_id: document.id, name: "Concept 2")

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      # Select both concepts
      view
      |> expand_concept(concept1.id)
      |> element("input[phx-value-id='#{concept1.id}']")
      |> render_click()

      view
      |> expand_concept(concept2.id)
      |> element("input[phx-value-id='#{concept2.id}']")
      |> render_click()

      # Verify both are selected
      assert has_element?(view, "button", "Generate (2)")
    end
  end

  describe "generate_diagrams" do
    test "clears selection after clicking generate", %{conn: conn} do
      document = fixture(:document)
      concept1 = fixture(:concept, document_id: document.id)
      concept2 = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      # Select both concepts
      view
      |> expand_concept(concept1.id)
      |> element("input[phx-value-id='#{concept1.id}']")
      |> render_click()

      view
      |> expand_concept(concept2.id)
      |> element("input[phx-value-id='#{concept2.id}']")
      |> render_click()

      # Verify both are selected before generation
      assert has_element?(view, "button", "Generate (2)")

      # Generate diagrams
      view
      |> element("button", "Generate (2)")
      |> render_click()

      # Verify jobs were enqueued
      assert [%{args: %{"concept_id" => _}}, %{args: %{"concept_id" => _}}] =
               all_enqueued(worker: DiagramForge.Diagrams.Workers.GenerateDiagramJob)

      # Verify selection was cleared
      refute view
             |> element("input[checked]")
             |> has_element?()

      # Verify generate button with count is gone
      refute has_element?(view, "button", ~r/Generate \(\d+\)/)
    end
  end

  describe "select_diagram" do
    test "displays selected diagram in preview area", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      diagram =
        fixture(:diagram,
          document_id: document.id,
          concept_id: concept.id,
          title: "Test Diagram",
          diagram_source: "graph TD\nA-->B"
        )

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      view
      |> expand_concept(concept.id)
      |> element("[phx-click='select_diagram'][phx-value-id='#{diagram.id}']")
      |> render_click()

      html = render(view)

      # Verify diagram is displayed
      assert html =~ "Test Diagram"
      assert html =~ "graph TD"
      assert html =~ "A--&gt;B"
      assert has_element?(view, "#mermaid-preview")
    end
  end

  describe "update_prompt" do
    test "updates prompt assign", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Update prompt
      view
      |> element("textarea[name='prompt']")
      |> render_change(%{"prompt" => "Create a GenServer diagram"})

      # The prompt should be in the textarea value
      assert view
             |> element("textarea[name='prompt']")
             |> render() =~ "Create a GenServer diagram"
    end
  end

  describe "generate_from_prompt" do
    test "generates diagram from prompt and displays it", %{conn: conn} do
      ai_response = %{
        "title" => "GenServer Flow",
        "domain" => "elixir",
        "level" => "intermediate",
        "tags" => ["otp"],
        "mermaid" => "flowchart TD\n  A[Start] --> B[GenServer]",
        "summary" => "Shows GenServer flow",
        "notes_md" => "# Notes\n\nTest notes"
      }

      expect(MockAIClient, :chat!, fn _messages, _opts ->
        Jason.encode!(ai_response)
      end)

      {:ok, view, _html} = live(conn, ~p"/")

      # Update prompt
      view
      |> element("textarea[name='prompt']")
      |> render_change(%{"prompt" => "Create a GenServer diagram"})

      # Generate diagram - MockAIClient will be used automatically
      view
      |> element("form[phx-submit='generate_from_prompt']")
      |> render_submit()

      html = render(view)

      # Verify diagram was generated and is displayed
      assert html =~ "GenServer Flow"
      assert html =~ "Shows GenServer flow"
      assert html =~ "💾 Save Diagram"
      assert html =~ "🗑️ Discard"

      # Diagram should NOT be in database yet (needs to be saved)
      diagrams = Diagrams.list_diagrams()
      assert diagrams == []

      # Click Save button
      view
      |> element("button", "💾 Save Diagram")
      |> render_click()

      # Now diagram should be in database
      diagrams = Diagrams.list_diagrams()
      assert length(diagrams) == 1
      diagram = hd(diagrams)
      assert diagram.title == "GenServer Flow"
    end

    test "does not create diagram when prompt is empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Try to submit with empty prompt
      view
      |> element("form[phx-submit='generate_from_prompt']")
      |> render_submit()

      # Verify no diagram was created
      diagrams = Diagrams.list_diagrams()
      assert diagrams == []
    end

    test "submit button is disabled when prompt is empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Verify submit button is disabled initially
      assert view
             |> element("button[type='submit'][disabled]", "Generate Diagram")
             |> has_element?()
    end
  end

  describe "handle_info - document_updated" do
    test "refreshes document list when document is updated", %{conn: conn} do
      document = fixture(:document, title: "Original Title")

      {:ok, view, _html} = live(conn, ~p"/")

      # Verify original title
      assert render(view) =~ "Original Title"

      # Simulate document update via PubSub
      {:ok, updated_doc} = Diagrams.update_document(document, %{title: "Updated Title"})

      Phoenix.PubSub.broadcast(
        DiagramForge.PubSub,
        "documents",
        {:document_updated, updated_doc.id}
      )

      # Give LiveView time to process the message
      :timer.sleep(50)

      # Verify updated title
      assert render(view) =~ "Updated Title"
      refute render(view) =~ "Original Title"
    end

    test "updates selected document when it is updated", %{conn: conn} do
      document = fixture(:document, status: :uploaded)

      {:ok, view, _html} = live(conn, ~p"/")

      # Select the document
      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      # Update document status
      {:ok, updated_doc} = Diagrams.update_document(document, %{status: :processing})

      Phoenix.PubSub.broadcast(
        DiagramForge.PubSub,
        "documents",
        {:document_updated, updated_doc.id}
      )

      :timer.sleep(50)

      # Verify status badge shows processing
      assert has_element?(view, "span", "Processing...")
    end
  end

  describe "handle_info - diagram_created" do
    test "refreshes diagrams when new diagram is created", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Select document
      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      # Create a new diagram
      diagram = fixture(:diagram, document_id: document.id, concept_id: concept.id)

      # Broadcast diagram creation
      Phoenix.PubSub.broadcast(
        DiagramForge.PubSub,
        "diagrams",
        {:diagram_created, diagram.id}
      )

      :timer.sleep(50)

      # Expand the concept to see the diagram
      view
      |> expand_concept(concept.id)

      # Verify diagram appears in the list
      assert render(view) =~ diagram.title
    end

    test "ignores diagram creation when no document is selected", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Don't select any document

      # Create a diagram
      diagram = fixture(:diagram, document_id: document.id, concept_id: concept.id)

      # Broadcast diagram creation
      Phoenix.PubSub.broadcast(
        DiagramForge.PubSub,
        "diagrams",
        {:diagram_created, diagram.id}
      )

      :timer.sleep(50)

      # Verify diagram doesn't appear (since no document is selected)
      refute render(view) =~ diagram.title
    end
  end

  describe "file upload" do
    test "displays upload area and accepts files", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      # Verify upload area exists
      assert has_element?(view, "#upload-form")
      assert render(view) =~ "Click or drag PDF/MD"

      # Verify upload button is disabled when no file is selected
      assert view
             |> element("button[type='submit'][disabled]")
             |> has_element?()
    end
  end

  describe "generation progress tracking" do
    test "displays progress bar during diagram generation", %{conn: conn} do
      document = fixture(:document)
      concept1 = fixture(:concept, document_id: document.id)
      concept2 = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      # Select both concepts
      view
      |> expand_concept(concept1.id)
      |> element("input[phx-value-id='#{concept1.id}']")
      |> render_click()

      view
      |> expand_concept(concept2.id)
      |> element("input[phx-value-id='#{concept2.id}']")
      |> render_click()

      # Generate diagrams
      view
      |> element("button", "Generate (2)")
      |> render_click()

      html = render(view)

      # Verify progress bar appears
      assert html =~ "Generating: 0 of 2"
    end

    test "updates progress when generation completes", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      view
      |> expand_concept(concept.id)
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      view
      |> element("button", "Generate (1)")
      |> render_click()

      # Verify progress bar appears initially
      assert render(view) =~ "Generating: 0 of 1"

      # Create a diagram and simulate completion event
      diagram = fixture(:diagram, document_id: document.id, concept_id: concept.id)

      send(
        view.pid,
        {:generation_completed, concept.id, diagram.id}
      )

      :timer.sleep(50)

      html = render(view)

      # Verify progress bar disappears after all generations complete
      refute html =~ "Generating:"

      # Verify diagram appears in list
      assert html =~ diagram.title
    end

    test "handles generation_started event", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      # Simulate generation started
      send(view.pid, {:generation_started, concept.id})

      :timer.sleep(50)

      # Should not crash - this is a no-op event
      assert view |> element("h1", "DiagramForge Studio") |> has_element?()
    end

    test "handles generation_failed event with error details", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id, name: "Test Concept")

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      view
      |> expand_concept(concept.id)
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      view
      |> element("button", "Generate (1)")
      |> render_click()

      # Simulate generation failure with error details
      send(
        view.pid,
        {:generation_failed, concept.id, %{status: 503}, :transient, :medium}
      )

      :timer.sleep(50)

      html = render(view)

      # Verify error severity badge appears
      assert html =~ "⚠"
      assert html =~ "⚠"

      # Verify concept is no longer in generating_concepts
      refute html =~ "Generating:"
    end

    test "resets progress tracking when switching documents", %{conn: conn} do
      doc1 = fixture(:document, title: "Doc 1")
      doc2 = fixture(:document, title: "Doc 2")
      concept1 = fixture(:concept, document_id: doc1.id)
      _concept2 = fixture(:concept, document_id: doc2.id)

      {:ok, view, _html} = live(conn, ~p"/")

      # Select first document and start generation
      view
      |> element("[phx-value-id='#{doc1.id}']")
      |> render_click()

      view
      |> expand_concept(concept1.id)
      |> element("input[phx-value-id='#{concept1.id}']")
      |> render_click()

      view
      |> element("button", "Generate (1)")
      |> render_click()

      # Verify progress bar appears
      assert render(view) =~ "Generating: 0 of 1"

      # Switch to second document
      view
      |> element("[phx-value-id='#{doc2.id}']")
      |> render_click()

      # Verify progress was reset
      refute render(view) =~ "Generating:"
    end
  end

  describe "error severity badges" do
    test "displays critical severity badge in red", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id, name: "Failed Concept")

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      view
      |> expand_concept(concept.id)
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      view
      |> element("button", "Generate (1)")
      |> render_click()

      # Simulate critical authentication failure
      send(
        view.pid,
        {:generation_failed, concept.id, %{status: 401}, :authentication, :critical}
      )

      :timer.sleep(50)

      html = render(view)

      # Verify critical badge with red styling
      assert html =~ "⚠"
      assert html =~ "bg-red-900/50"
    end

    test "displays high severity badge in orange", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      view
      |> expand_concept(concept.id)
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      view
      |> element("button", "Generate (1)")
      |> render_click()

      # Simulate high severity rate limit error
      send(
        view.pid,
        {:generation_failed, concept.id, %{status: 429}, :rate_limit, :high}
      )

      :timer.sleep(50)

      html = render(view)

      # Verify high severity badge with orange styling
      assert html =~ "⚠"
      assert html =~ "bg-orange-900/50"
    end

    test "displays medium severity badge in yellow", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      view
      |> expand_concept(concept.id)
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      view
      |> element("button", "Generate (1)")
      |> render_click()

      # Simulate medium severity transient error
      send(
        view.pid,
        {:generation_failed, concept.id, %{status: 503}, :transient, :medium}
      )

      :timer.sleep(50)

      html = render(view)

      # Verify medium severity badge with yellow styling
      assert html =~ "⚠"
      assert html =~ "bg-yellow-900/50"
    end

    test "displays low severity badge in blue", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      view
      |> expand_concept(concept.id)
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      view
      |> element("button", "Generate (1)")
      |> render_click()

      # Simulate low severity permanent error
      send(
        view.pid,
        {:generation_failed, concept.id, %{status: 404}, :permanent, :low}
      )

      :timer.sleep(50)

      html = render(view)

      # Verify low severity badge with blue styling
      assert html =~ "⚠"
      assert html =~ "bg-blue-900/50"
    end

    test "clears error badges when generating new diagrams", %{conn: conn} do
      document = fixture(:document)
      concept = fixture(:concept, document_id: document.id)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      view
      |> expand_concept(concept.id)
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      view
      |> element("button", "Generate (1)")
      |> render_click()

      # Simulate failure
      send(
        view.pid,
        {:generation_failed, concept.id, %{status: 503}, :transient, :medium}
      )

      :timer.sleep(50)

      # Verify error badge appears
      assert render(view) =~ "⚠"

      # Regenerate (concept is still expanded from earlier)
      view
      |> element("input[phx-value-id='#{concept.id}']")
      |> render_click()

      view
      |> element("button", "Generate (1)")
      |> render_click()

      # Verify error badge was cleared
      refute render(view) =~ "⚠"
    end
  end

  # Helper function to expand a concept before interacting with its content
  defp expand_concept(view, concept_id) do
    view
    |> element("[phx-click='toggle_concept_expand'][phx-value-id='#{concept_id}']")
    |> render_click()

    view
  end
end
