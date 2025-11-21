defmodule DiagramForge.Diagrams do
  @moduledoc """
  The Diagrams context - handles documents, concepts, and diagrams.
  """

  import Ecto.Query, warn: false
  alias DiagramForge.Repo

  alias DiagramForge.Diagrams.{Concept, Diagram, Document}
  alias DiagramForge.Diagrams.Workers.ProcessDocumentJob

  # Documents

  @doc """
  Returns the list of documents.

  ## Examples

      iex> list_documents()
      [%Document{}, ...]

  """
  def list_documents do
    Repo.all(from d in Document, order_by: [desc: d.inserted_at])
  end

  @doc """
  Gets a single document.

  Raises `Ecto.NoResultsError` if the Document does not exist.
  """
  def get_document!(id), do: Repo.get!(Document, id)

  @doc """
  Creates a document and enqueues it for processing.

  ## Examples

      iex> upload_document(%{title: "My Doc", source_type: :pdf, path: "/path/to/doc.pdf"})
      {:ok, %Document{}}

  """
  def upload_document(attrs \\ %{}) do
    changeset = Document.changeset(%Document{}, attrs)

    case Repo.insert(changeset) do
      {:ok, document} ->
        # Enqueue the background job to process this document
        %{"document_id" => document.id}
        |> ProcessDocumentJob.new()
        |> Oban.insert()

        {:ok, document}

      {:error, changeset} ->
        {:error, changeset}
    end
  end

  # Concepts

  @doc """
  Lists concepts for a given document.
  """
  def list_concepts_for_document(document_id) do
    Repo.all(
      from c in Concept,
        where: c.document_id == ^document_id,
        order_by: [desc: c.importance, asc: c.name]
    )
  end

  @doc """
  Gets a single concept.
  """
  def get_concept!(id), do: Repo.get!(Concept, id)

  # Diagrams

  @doc """
  Lists all diagrams.
  """
  def list_diagrams do
    Repo.all(from d in Diagram, order_by: [desc: d.inserted_at])
  end

  @doc """
  Lists diagrams for a given concept.
  """
  def list_diagrams_for_concept(concept_id) do
    Repo.all(
      from d in Diagram,
        where: d.concept_id == ^concept_id,
        order_by: [desc: d.inserted_at]
    )
  end

  @doc """
  Gets a single diagram.
  """
  def get_diagram!(id), do: Repo.get!(Diagram, id)

  @doc """
  Gets a diagram by slug.
  """
  def get_diagram_by_slug(slug), do: Repo.get_by(Diagram, slug: slug)
end
