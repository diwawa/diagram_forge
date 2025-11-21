defmodule DiagramForge.Diagrams.ConceptTest do
  use DiagramForge.DataCase, async: true

  alias DiagramForge.Diagrams.Concept
  alias DiagramForge.Repo

  describe "Concept schema" do
    test "has correct default values" do
      concept = %Concept{}
      assert concept.level == :beginner
      assert concept.importance == 3
    end

    test "validates required fields" do
      changeset = Concept.changeset(%Concept{}, %{})

      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).category
    end

    test "validates importance range" do
      document = fixture(:document)

      # Too low
      changeset = build(:concept, document: document, importance: 0)
      {:error, changeset} = Repo.insert(changeset)
      assert "must be greater than or equal to 1" in errors_on(changeset).importance

      # Too high
      changeset = build(:concept, document: document, importance: 6)
      {:error, changeset} = Repo.insert(changeset)
      assert "must be less than or equal to 5" in errors_on(changeset).importance

      # Valid values
      for importance <- 1..5 do
        changeset = build(:concept, document: document, importance: importance)
        assert {:ok, _} = Repo.insert(changeset)
      end
    end

    test "allows valid level values" do
      document = fixture(:document)

      for level <- [:beginner, :intermediate, :advanced] do
        changeset = build(:concept, document: document, level: level)
        assert {:ok, _} = Repo.insert(changeset)
      end
    end

    test "belongs to a document" do
      document = fixture(:document)
      concept = fixture(:concept, document: document)

      loaded_concept = Repo.preload(concept, :document)
      assert loaded_concept.document.id == document.id
    end

    test "creates concept with all fields" do
      document = fixture(:document)

      changeset =
        build(:concept,
          document: document,
          name: "GenServer",
          short_description: "OTP behavior for processes",
          category: "elixir",
          level: :intermediate,
          importance: 5
        )

      assert {:ok, concept} = Repo.insert(changeset)
      assert concept.name == "GenServer"
      assert concept.short_description == "OTP behavior for processes"
      assert concept.category == "elixir"
      assert concept.level == :intermediate
      assert concept.importance == 5
    end
  end
end
