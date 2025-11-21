defmodule DiagramForge.Diagrams.DiagramTest do
  use DiagramForge.DataCase, async: true

  alias DiagramForge.Diagrams.Diagram
  alias DiagramForge.Repo

  describe "Diagram schema" do
    test "has correct default values" do
      diagram = %Diagram{}
      assert diagram.level == :beginner
      assert diagram.format == :mermaid
      assert diagram.tags == []
    end

    test "validates required fields" do
      changeset = Diagram.changeset(%Diagram{}, %{})

      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).diagram_source
      assert "can't be blank" in errors_on(changeset).slug
    end

    test "enforces unique slug" do
      _diagram1 = fixture(:diagram, slug: "unique-slug")

      changeset = build(:diagram, slug: "unique-slug")
      {:error, changeset} = Repo.insert(changeset)

      assert "has already been taken" in errors_on(changeset).slug
    end

    test "allows valid format values" do
      for format <- [:mermaid, :plantuml] do
        changeset = build(:diagram, format: format)
        assert {:ok, _} = Repo.insert(changeset)
      end
    end

    test "allows valid level values" do
      for level <- [:beginner, :intermediate, :advanced] do
        changeset = build(:diagram, level: level)
        assert {:ok, _} = Repo.insert(changeset)
      end
    end

    test "optionally belongs to a concept" do
      document = fixture(:document)
      concept = fixture(:concept, document: document)
      diagram = fixture(:diagram, concept: concept)

      loaded = Repo.preload(diagram, :concept)
      assert loaded.concept.id == concept.id
    end

    test "optionally belongs to a document" do
      document = fixture(:document)
      diagram = fixture(:diagram, document: document)

      loaded = Repo.preload(diagram, :document)
      assert loaded.document.id == document.id
    end

    test "creates diagram with all fields" do
      changeset =
        build(:diagram,
          title: "GenServer Flow",
          slug: "genserver-flow",
          domain: "elixir",
          level: :advanced,
          tags: ["otp", "concurrency"],
          format: :mermaid,
          diagram_source: "flowchart TD\n  A --> B",
          summary: "Shows GenServer message flow",
          notes_md: "- Call\n- Cast\n- Info"
        )

      assert {:ok, diagram} = Repo.insert(changeset)
      assert diagram.title == "GenServer Flow"
      assert diagram.slug == "genserver-flow"
      assert diagram.domain == "elixir"
      assert diagram.level == :advanced
      assert diagram.tags == ["otp", "concurrency"]
      assert diagram.format == :mermaid
      assert diagram.diagram_source == "flowchart TD\n  A --> B"
      assert diagram.summary == "Shows GenServer message flow"
      assert diagram.notes_md == "- Call\n- Cast\n- Info"
    end
  end
end
