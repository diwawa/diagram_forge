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
      fixture(:diagram, concept: concept)
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
      concept1 = fixture(:concept, document: doc1)
      _concept2 = fixture(:concept, document: doc2)

      {:ok, view, _html} = live(conn, ~p"/")

      # Select first document and toggle a concept
      view
      |> element("[phx-value-id='#{doc1.id}']")
      |> render_click()

      show_all_concepts(view)

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

      # Verify selected concepts were cleared (check for concept selection checkboxes specifically)
      refute view
             |> element("input[phx-click='toggle_concept'][checked]")
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

      show_all_concepts(view)

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

      show_all_concepts(view)

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

      show_all_concepts(view)

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

      show_all_concepts(view)

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
      fixture(:diagram, concept: concept)

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

      show_all_concepts(view)

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
      fixture(:diagram, concept: concept)

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
      fixture(:diagram, concept: concept)

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
      concept1 = fixture(:concept, document: document)
      concept2 = fixture(:concept, document: document)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      show_all_concepts(view)

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
      concept = fixture(:concept, document: document)

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      show_all_concepts(view)

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
      concept = fixture(:concept, document: document)
      fixture(:diagram, concept: concept)

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
      concept = fixture(:concept, document: document, name: "Test Concept")

      {:ok, view, _html} = live(conn, ~p"/")

      view
      |> element("[phx-value-id='#{document.id}']")
      |> render_click()

      show_all_concepts(view)

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
      concept1 = fixture(:concept, document: doc1)
      _concept2 = fixture(:concept, document: doc2)

      {:ok, view, _html} = live(conn, ~p"/")

      # Select first document and start generation
      view
      |> element("[phx-value-id='#{doc1.id}']")
      |> render_click()

      show_all_concepts(view)

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

      show_all_concepts(view)

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

      show_all_concepts(view)

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

      show_all_concepts(view)

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

      show_all_concepts(view)

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

      show_all_concepts(view)

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

  describe "pagination" do
    test "loads with default pagination params from URL", %{conn: conn} do
      # Create 15 concepts to test pagination (padded for correct alphabetical sorting)
      for i <- 1..15 do
        concept =
          fixture(:concept, name: "Concept #{String.pad_leading(Integer.to_string(i), 2, "0")}")

        fixture(:diagram, concept: concept)
      end

      {:ok, _view, html} = live(conn, ~p"/?page=1&page_size=5")

      # Should show first 5 concepts
      assert html =~ "Concept 01"
      assert html =~ "Concept 05"
      # Should not show concepts beyond page 1
      refute html =~ "Concept 06"

      # Should show correct page info
      assert html =~ "Page 1 of 3"
      assert html =~ "15 total"
    end

    test "changing page size updates URL and displays correct number of items", %{conn: conn} do
      # Create 15 concepts (padded for correct alphabetical sorting)
      for i <- 1..15 do
        concept =
          fixture(:concept, name: "Concept #{String.pad_leading(Integer.to_string(i), 2, "0")}")

        fixture(:diagram, concept: concept)
      end

      {:ok, view, _html} = live(conn, ~p"/")

      # Initially shows 10 items (default page size)
      html = render(view)
      assert html =~ "Concept 01"
      assert html =~ "Concept 10"
      refute html =~ "Concept 11"

      # Change page size to 5
      view
      |> element("form[phx-change='concepts_change_page_size']")
      |> render_change(%{"page_size" => "5"})

      # Verify URL was updated
      assert_patch(view, ~p"/?page=1&page_size=5&only_with_diagrams=true")

      # Now should only show 5 items
      html = render(view)
      assert html =~ "Concept 01"
      assert html =~ "Concept 05"
      refute html =~ "Concept 06"

      # Verify pagination info updated
      assert html =~ "Page 1 of 3"
    end

    test "navigating pages updates URL and displays correct items", %{conn: conn} do
      # Create 15 concepts (padded for correct alphabetical sorting)
      for i <- 1..15 do
        concept =
          fixture(:concept, name: "Concept #{String.pad_leading(Integer.to_string(i), 2, "0")}")

        fixture(:diagram, concept: concept)
      end

      {:ok, view, _html} = live(conn, ~p"/?page=1&page_size=5")

      # Click next page
      view
      |> element("button[phx-value-page='2']")
      |> render_click()

      # Verify URL was updated
      assert_patch(view, ~p"/?page=2&page_size=5&only_with_diagrams=true")

      # Verify we see page 2 items (concepts 6-10)
      html = render(view)
      refute html =~ "Concept 05"
      assert html =~ "Concept 06"
      assert html =~ "Concept 10"
      refute html =~ "Concept 11"

      # Verify page info
      assert html =~ "Page 2 of 3"
    end

    test "bookmarkable URLs load correct page and size", %{conn: conn} do
      # Create 30 concepts (padded for correct alphabetical sorting)
      for i <- 1..30 do
        concept =
          fixture(:concept, name: "Concept #{String.pad_leading(Integer.to_string(i), 2, "0")}")

        fixture(:diagram, concept: concept)
      end

      # Load page 2 with page size 10 directly from URL
      {:ok, _view, html} = live(conn, ~p"/?page=2&page_size=10")

      # Should show concepts 11-20
      refute html =~ "Concept 10"
      assert html =~ "Concept 11"
      assert html =~ "Concept 20"
      refute html =~ "Concept 21"

      # Verify pagination info
      assert html =~ "Page 2 of 3"
      assert html =~ "30 total"
    end

    test "changing page size resets to page 1", %{conn: conn} do
      # Create 20 concepts (padded for correct alphabetical sorting)
      for i <- 1..20 do
        concept =
          fixture(:concept, name: "Concept #{String.pad_leading(Integer.to_string(i), 2, "0")}")

        fixture(:diagram, concept: concept)
      end

      # Start on page 2
      {:ok, view, _html} = live(conn, ~p"/?page=2&page_size=5")

      # Verify we're on page 2 (concepts 6-10)
      html = render(view)
      assert html =~ "Concept 06"
      assert html =~ "Page 2 of 4"

      # Change page size
      view
      |> element("form[phx-change='concepts_change_page_size']")
      |> render_change(%{"page_size" => "10"})

      # Should reset to page 1
      assert_patch(view, ~p"/?page=1&page_size=10&only_with_diagrams=true")

      # Should show first 10 concepts
      html = render(view)
      assert html =~ "Concept 01"
      assert html =~ "Concept 10"
      assert html =~ "Page 1 of 2"
    end
  end

  describe "diagram search" do
    test "search input is visible in the UI", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/")

      assert has_element?(
               view,
               "input[name='search'][placeholder='Search diagrams (min 3 chars)...']"
             )
    end

    test "searching with less than 3 characters does not filter", %{conn: conn} do
      concept1 = fixture(:concept, name: "Concept Alpha")
      fixture(:diagram, concept: concept1, title: "Alpha Diagram")

      concept2 = fixture(:concept, name: "Concept Beta")
      fixture(:diagram, concept: concept2, title: "Beta Diagram")

      {:ok, view, _html} = live(conn, ~p"/")

      # Search with 2 characters (below minimum)
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "Al"})

      # Should show both concepts (no filtering)
      html = render(view)
      assert html =~ "Concept Alpha"
      assert html =~ "Concept Beta"

      # URL should be reset to page 1 without search_query
      assert_patch(view, ~p"/?page=1&page_size=10&only_with_diagrams=true")
    end

    test "searching with 3+ characters filters concepts by diagram title", %{conn: conn} do
      concept1 = fixture(:concept, name: "Concept Alpha")
      fixture(:diagram, concept: concept1, title: "Alpha Diagram")

      concept2 = fixture(:concept, name: "Concept Beta")
      fixture(:diagram, concept: concept2, title: "Beta Diagram")

      {:ok, view, _html} = live(conn, ~p"/")

      # Search for "Alpha" (matches diagram title)
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "Alpha"})

      # Should show only Concept Alpha
      html = render(view)
      assert html =~ "Concept Alpha"
      refute html =~ "Concept Beta"

      # URL should include search_query param
      assert_patch(view, ~p"/?search_query=Alpha&page=1&page_size=10&only_with_diagrams=true")
    end

    test "searching filters concepts by diagram summary", %{conn: conn} do
      concept1 = fixture(:concept, name: "Concept One")
      fixture(:diagram, concept: concept1, title: "Diagram 1", summary: "This is about Phoenix")

      concept2 = fixture(:concept, name: "Concept Two")
      fixture(:diagram, concept: concept2, title: "Diagram 2", summary: "This is about Elixir")

      {:ok, view, _html} = live(conn, ~p"/")

      # Search for "Phoenix" (matches diagram summary)
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "Phoenix"})

      # Should show only Concept One
      html = render(view)
      assert html =~ "Concept One"
      refute html =~ "Concept Two"
    end

    test "search is case-insensitive", %{conn: conn} do
      concept = fixture(:concept, name: "Test Concept")
      fixture(:diagram, concept: concept, title: "GenServer Diagram")

      {:ok, view, _html} = live(conn, ~p"/")

      # Search with lowercase
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "genserver"})

      # Should find the diagram
      html = render(view)
      assert html =~ "Test Concept"
    end

    test "search shows Clear button when active", %{conn: conn} do
      concept = fixture(:concept, name: "Test Concept")
      fixture(:diagram, concept: concept, title: "Test Diagram")

      {:ok, view, _html} = live(conn, ~p"/")

      # Initially no search Clear button
      refute has_element?(view, "button[phx-click='clear_search']")

      # Search for something
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "Test"})

      # Search Clear button should appear
      assert has_element?(view, "button[phx-click='clear_search']", "✕ Clear")
    end

    test "Clear button clears search query", %{conn: conn} do
      concept1 = fixture(:concept, name: "Concept Alpha")
      fixture(:diagram, concept: concept1, title: "Alpha Diagram")

      concept2 = fixture(:concept, name: "Concept Beta")
      fixture(:diagram, concept: concept2, title: "Beta Diagram")

      {:ok, view, _html} = live(conn, ~p"/")

      # Search for "Alpha"
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "Alpha"})

      # Verify only Alpha is shown
      html = render(view)
      assert html =~ "Concept Alpha"
      refute html =~ "Concept Beta"

      # Click Clear button (next to search box)
      view
      |> element("button[phx-click='clear_search']")
      |> render_click()

      # Should show both concepts again
      html = render(view)
      assert html =~ "Concept Alpha"
      assert html =~ "Concept Beta"

      # URL should not have search_query param
      assert_patch(view, ~p"/?page=1&page_size=10&only_with_diagrams=true")
    end

    test "search query is preserved in URL for bookmarking", %{conn: conn} do
      concept = fixture(:concept, name: "Test Concept")
      fixture(:diagram, concept: concept, title: "Phoenix Framework")

      # Load page with search_query in URL
      {:ok, _view, html} = live(conn, ~p"/?search_query=Phoenix")

      # Should show filtered results
      assert html =~ "Test Concept"
    end

    test "search resets to page 1", %{conn: conn} do
      # Create 15 concepts with diagrams
      for i <- 1..15 do
        concept =
          fixture(:concept, name: "Concept #{String.pad_leading(Integer.to_string(i), 2, "0")}")

        fixture(:diagram, concept: concept, title: "Diagram #{i}")
      end

      # Start on page 2 with page size 5
      {:ok, view, _html} = live(conn, ~p"/?page=2&page_size=5")

      # Verify we're on page 2
      assert render(view) =~ "Page 2 of 3"

      # Perform a search
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "Diagram"})

      # Should reset to page 1
      assert_patch(view, ~p"/?search_query=Diagram&page=1&page_size=5&only_with_diagrams=true")
    end

    test "search works with document filter", %{conn: conn} do
      doc1 = fixture(:document, title: "Doc 1")
      concept1 = fixture(:concept, name: "Concept 1", document: doc1)
      fixture(:diagram, concept: concept1, title: "Phoenix Diagram", document: doc1)

      doc2 = fixture(:document, title: "Doc 2")
      concept2 = fixture(:concept, name: "Concept 2", document: doc2)
      fixture(:diagram, concept: concept2, title: "Elixir Diagram", document: doc2)

      {:ok, view, _html} = live(conn, ~p"/")

      # Select document 1
      view
      |> element("[phx-value-id='#{doc1.id}']")
      |> render_click()

      # Search for "Phoenix"
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "Phoenix"})

      # Should show only Concept 1
      html = render(view)
      assert html =~ "Concept 1"
      refute html =~ "Concept 2"
    end

    test "search updates concept count correctly", %{conn: conn} do
      concept1 = fixture(:concept, name: "Concept Alpha")
      fixture(:diagram, concept: concept1, title: "Alpha Diagram")

      concept2 = fixture(:concept, name: "Concept Beta")
      fixture(:diagram, concept: concept2, title: "Beta Diagram")

      concept3 = fixture(:concept, name: "Concept Gamma")
      fixture(:diagram, concept: concept3, title: "Gamma Diagram")

      {:ok, view, _html} = live(conn, ~p"/")

      # Initially shows 3 total
      assert render(view) =~ "3 total"

      # Search for "Alpha"
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "Alpha"})

      # Should show 1 total
      assert render(view) =~ "1 total"
    end

    test "empty search query shows all concepts", %{conn: conn} do
      concept1 = fixture(:concept, name: "Concept Alpha")
      fixture(:diagram, concept: concept1, title: "Alpha Diagram")

      concept2 = fixture(:concept, name: "Concept Beta")
      fixture(:diagram, concept: concept2, title: "Beta Diagram")

      {:ok, view, _html} = live(conn, ~p"/")

      # Search for something first
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => "Alpha"})

      # Verify only Alpha is shown
      refute render(view) =~ "Concept Beta"

      # Clear search by entering empty string
      view
      |> element("form[phx-change='search_diagrams']")
      |> render_change(%{"search" => ""})

      # Should show all concepts
      html = render(view)
      assert html =~ "Concept Alpha"
      assert html =~ "Concept Beta"
    end
  end

  # Helper function to expand a concept before interacting with its content
  defp expand_concept(view, concept_id) do
    view
    |> element("[phx-click='toggle_concept_expand'][phx-value-id='#{concept_id}']")
    |> render_click()

    view
  end

  # Helper function to turn off the "only with diagrams" filter
  defp show_all_concepts(view) do
    view
    |> element("input[type='checkbox'][phx-click='toggle_show_only_with_diagrams'][checked]")
    |> render_click()

    view
  end
end
