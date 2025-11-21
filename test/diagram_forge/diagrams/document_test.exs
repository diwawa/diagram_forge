defmodule DiagramForge.Diagrams.DocumentTest do
  use DiagramForge.DataCase, async: true

  alias DiagramForge.Diagrams.Document
  alias DiagramForge.Repo

  describe "Document schema" do
    test "has correct default status" do
      doc = %Document{}
      assert doc.status == :uploaded
    end

    test "validates required fields" do
      changeset = Document.changeset(%Document{}, %{})

      assert "can't be blank" in errors_on(changeset).title
      assert "can't be blank" in errors_on(changeset).source_type
      assert "can't be blank" in errors_on(changeset).path
    end

    test "allows valid source_type values" do
      for source_type <- [:pdf, :markdown] do
        doc = build(:document, source_type: source_type)
        assert {:ok, _} = Repo.insert(doc)
      end
    end

    test "allows valid status values" do
      for status <- [:uploaded, :processing, :ready, :error] do
        doc = build(:document, status: status)
        assert {:ok, _} = Repo.insert(doc)
      end
    end

    test "creates document with all required fields" do
      doc =
        build(:document,
          title: "Test Doc",
          source_type: :pdf,
          path: "/test/path.pdf"
        )

      assert {:ok, inserted} = Repo.insert(doc)
      assert inserted.title == "Test Doc"
      assert inserted.source_type == :pdf
      assert inserted.path == "/test/path.pdf"
      assert inserted.status == :uploaded
    end

    test "allows error_message to be set" do
      doc = build(:document, status: :error, error_message: "Test error")
      assert {:ok, inserted} = Repo.insert(doc)
      assert inserted.error_message == "Test error"
    end
  end
end
