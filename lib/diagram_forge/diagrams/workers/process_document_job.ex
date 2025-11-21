defmodule DiagramForge.Diagrams.Workers.ProcessDocumentJob do
  @moduledoc """
  Oban worker that processes newly uploaded documents.

  This job:
  1. Extracts text from the document (PDF or Markdown)
  2. Runs concept extraction on the extracted text
  3. Updates the document status accordingly
  """

  use Oban.Worker, queue: :documents

  alias DiagramForge.Diagrams.{ConceptExtractor, Document, DocumentIngestor}
  alias DiagramForge.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    doc_id = args["document_id"]

    opts =
      if args["ai_client"], do: [ai_client: String.to_existing_atom(args["ai_client"])], else: []

    doc = Repo.get!(Document, doc_id)

    doc
    |> Document.changeset(%{status: :processing})
    |> Repo.update!()

    case DocumentIngestor.extract_text(doc) do
      {:ok, text} ->
        # Update raw_text and extract concepts
        doc =
          doc
          |> Document.changeset(%{raw_text: text})
          |> Repo.update!()

        ConceptExtractor.extract_for_document(doc, opts)

        # Update status to ready in a single changeset with raw_text to ensure both are persisted
        doc
        |> Document.changeset(%{raw_text: text, status: :ready})
        |> Repo.update!()

        :ok

      {:error, reason} ->
        doc
        |> Document.changeset(%{status: :error, error_message: reason})
        |> Repo.update()

        {:error, reason}
    end
  rescue
    e ->
      # Extract doc_id from args since it's not in scope here
      doc_id = args["document_id"]
      doc = Repo.get(Document, doc_id)

      if doc do
        doc
        |> Document.changeset(%{status: :error, error_message: Exception.message(e)})
        |> Repo.update()
      end

      {:error, Exception.message(e)}
  end
end
