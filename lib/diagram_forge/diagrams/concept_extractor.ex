defmodule DiagramForge.Diagrams.ConceptExtractor do
  @moduledoc """
  Extracts concepts from documents using LLM-powered analysis.
  """

  alias DiagramForge.AI.Client
  alias DiagramForge.AI.Prompts
  alias DiagramForge.Diagrams.{Concept, Document, DocumentIngestor}
  alias DiagramForge.Repo

  @doc """
  Extracts concepts from a document's raw text and stores them in the database.

  The document's `raw_text` is chunked and each chunk is analyzed by the LLM.
  Concepts are deduplicated by lowercased name across all chunks.

  Returns a list of inserted/updated concept records.

  ## Options

    * `:ai_client` - AI client module to use (defaults to DiagramForge.AI.Client)
  """
  def extract_for_document(%Document{} = doc, opts \\ []) do
    ai_client = opts[:ai_client] || Client
    text = doc.raw_text
    chunks = DocumentIngestor.chunk_text(text)

    chunks
    |> Enum.with_index()
    |> Enum.reduce(%{}, fn {chunk, _idx}, acc ->
      concepts = extract_concepts_from_chunk(chunk, ai_client)
      merge_concepts(concepts, acc)
    end)
    |> Map.values()
    |> Enum.map(&insert_or_update_concept(doc, &1))
  end

  defp extract_concepts_from_chunk(chunk, ai_client) do
    user = Prompts.concept_user_prompt(chunk)

    json =
      ai_client.chat!(
        [
          %{"role" => "system", "content" => Prompts.concept_system_prompt()},
          %{"role" => "user", "content" => user}
        ],
        []
      )
      |> Jason.decode!()

    json["concepts"] || []
  end

  defp merge_concepts(concepts, acc) do
    Enum.reduce(concepts, acc, fn c, acc2 ->
      key = String.downcase(c["name"] || "")

      if key == "" do
        acc2
      else
        Map.put_new(acc2, key, c)
      end
    end)
  end

  defp insert_or_update_concept(doc, attrs) do
    existing =
      Repo.get_by(Concept,
        document_id: doc.id,
        name: attrs["name"]
      )

    params = %{
      document_id: doc.id,
      name: attrs["name"],
      short_description: attrs["short_description"],
      category: attrs["category"]
    }

    (existing || %Concept{})
    |> Concept.changeset(params)
    |> Repo.insert_or_update!()
  end
end
