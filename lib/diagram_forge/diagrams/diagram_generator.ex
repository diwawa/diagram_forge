defmodule DiagramForge.Diagrams.DiagramGenerator do
  @moduledoc """
  Generates Mermaid diagrams from concepts or free-form prompts using LLM.
  """

  import Ecto.Query

  alias DiagramForge.AI.Client
  alias DiagramForge.AI.Prompts
  alias DiagramForge.Diagrams.{Concept, Diagram, Document}
  alias DiagramForge.Repo

  @doc """
  Generates a diagram for a specific concept.

  Preloads the document, builds context from it, and uses the LLM
  to generate a Mermaid diagram.

  Returns `{:ok, diagram}` on success or `{:error, reason}` on failure.

  ## Options

    * `:ai_client` - AI client module to use (defaults to configured client)
  """
  def generate_for_concept(%Concept{} = concept, opts) do
    ai_client = opts[:ai_client] || ai_client()
    concept = Repo.preload(concept, :document)

    context_excerpt = build_context_excerpt(concept.document)

    user_prompt = Prompts.diagram_from_concept_user_prompt(concept, context_excerpt)

    json =
      ai_client.chat!(
        [
          %{"role" => "system", "content" => Prompts.diagram_system_prompt()},
          %{"role" => "user", "content" => user_prompt}
        ],
        []
      )
      |> Jason.decode!()

    attrs = %{
      concept_id: concept.id,
      document_id: concept.document_id,
      title: json["title"],
      slug: slugify(json["title"]),
      domain: json["domain"],
      tags: json["tags"] || [],
      format: :mermaid,
      diagram_source: json["mermaid"],
      summary: json["summary"],
      notes_md: json["notes_md"]
    }

    %Diagram{}
    |> Diagram.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Generates a diagram from a free-form text prompt.

  Returns `{:ok, diagram}` on success or `{:error, reason}` on failure.

  ## Options

    * `:ai_client` - AI client module to use (defaults to configured client)
  """
  def generate_from_prompt(text, opts) do
    ai_client = opts[:ai_client] || ai_client()
    user_prompt = Prompts.diagram_from_prompt_user_prompt(text)

    json =
      ai_client.chat!(
        [
          %{"role" => "system", "content" => Prompts.diagram_system_prompt()},
          %{"role" => "user", "content" => user_prompt}
        ],
        []
      )
      |> Jason.decode!()

    # Find or create the concept
    concept = find_or_create_concept(json["concept"])

    attrs = %{
      concept_id: concept && concept.id,
      title: json["title"],
      slug: slugify(json["title"]),
      domain: json["domain"],
      tags: json["tags"] || [],
      format: :mermaid,
      diagram_source: json["mermaid"],
      summary: json["summary"],
      notes_md: json["notes_md"]
    }

    changeset = Diagram.changeset(%Diagram{}, attrs)

    if changeset.valid? do
      diagram = Ecto.Changeset.apply_changes(changeset)
      {:ok, diagram}
    else
      {:error, changeset}
    end
  end

  defp find_or_create_concept(nil), do: nil

  defp find_or_create_concept(concept_attrs) when is_map(concept_attrs) do
    name = concept_attrs["name"]

    # If name is missing, we can't create a concept
    if is_nil(name) or String.trim(name) == "" do
      nil
    else
      # Look up concept globally by name (case-insensitive)
      existing =
        Repo.one(
          from c in Concept,
            where: fragment("LOWER(?)", c.name) == ^String.downcase(name),
            limit: 1
        )

      if existing do
        # Concept already exists globally, reuse it as-is
        existing
      else
        # Create new concept without a document (generated from prompt)
        %Concept{}
        |> Concept.changeset(%{
          document_id: nil,
          name: name,
          short_description: concept_attrs["short_description"],
          category: concept_attrs["category"]
        })
        |> Repo.insert!()
      end
    end
  end

  defp build_context_excerpt(%Document{raw_text: nil}), do: ""

  defp build_context_excerpt(%Document{raw_text: text}) do
    text
    |> String.split(~r/\n{2,}/)
    |> Enum.take(8)
    |> Enum.join("\n\n")
    |> String.slice(0, 3000)
  end

  defp slugify(nil), do: "diagram-#{:os.system_time(:millisecond)}"

  defp slugify(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9]+/, "-")
    |> String.trim("-")
  end

  defp ai_client do
    Application.get_env(:diagram_forge, :ai_client, Client)
  end
end
