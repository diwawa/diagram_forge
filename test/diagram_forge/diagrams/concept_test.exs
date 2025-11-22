defmodule DiagramForge.Diagrams.ConceptTest do
  use DiagramForge.DataCase, async: true

  alias DiagramForge.Diagrams.Concept
  alias DiagramForge.Repo

  describe "Concept schema" do
    test "validates required fields" do
      changeset = Concept.changeset(%Concept{}, %{})

      assert "can't be blank" in errors_on(changeset).name
      assert "can't be blank" in errors_on(changeset).category
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
          category: "elixir"
        )

      assert {:ok, concept} = Repo.insert(changeset)
      assert concept.name == "GenServer"
      assert concept.short_description == "OTP behavior for processes"
      assert concept.category == "elixir"
    end
  end
end
