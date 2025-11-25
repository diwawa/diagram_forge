defmodule DiagramForge.AI.PromptTest do
  use DiagramForge.DataCase, async: true

  alias DiagramForge.AI.Prompt

  describe "changeset/2" do
    test "valid changeset with required fields" do
      attrs = %{key: "test_key", content: "Test content"}

      changeset = Prompt.changeset(%Prompt{}, attrs)

      assert changeset.valid?
    end

    test "valid changeset with all fields" do
      attrs = %{
        key: "test_key",
        content: "Test content",
        description: "Test description"
      }

      changeset = Prompt.changeset(%Prompt{}, attrs)

      assert changeset.valid?
      assert get_change(changeset, :key) == "test_key"
      assert get_change(changeset, :content) == "Test content"
      assert get_change(changeset, :description) == "Test description"
    end

    test "invalid without key" do
      attrs = %{content: "Test content"}

      changeset = Prompt.changeset(%Prompt{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).key
    end

    test "invalid without content" do
      attrs = %{key: "test_key"}

      changeset = Prompt.changeset(%Prompt{}, attrs)

      refute changeset.valid?
      assert "can't be blank" in errors_on(changeset).content
    end

    test "enforces unique key constraint" do
      # Create first prompt
      {:ok, _} =
        %Prompt{}
        |> Prompt.changeset(%{key: "unique_key", content: "First content"})
        |> Repo.insert()

      # Try to create second prompt with same key
      {:error, changeset} =
        %Prompt{}
        |> Prompt.changeset(%{key: "unique_key", content: "Second content"})
        |> Repo.insert()

      assert "has already been taken" in errors_on(changeset).key
    end

    test "allows updating content while keeping key" do
      {:ok, prompt} =
        %Prompt{}
        |> Prompt.changeset(%{key: "update_key", content: "Original"})
        |> Repo.insert()

      changeset = Prompt.changeset(prompt, %{content: "Updated"})

      assert changeset.valid?
      assert get_change(changeset, :content) == "Updated"
    end

    test "description is optional" do
      attrs = %{key: "no_desc", content: "Content without description"}

      changeset = Prompt.changeset(%Prompt{}, attrs)

      assert changeset.valid?
      assert is_nil(get_change(changeset, :description))
    end
  end
end
