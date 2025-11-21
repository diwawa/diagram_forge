defmodule DiagramForge.Diagrams.Workers.GenerateDiagramJob do
  @moduledoc """
  Oban worker that generates diagrams for concepts.
  """

  use Oban.Worker, queue: :diagrams

  alias DiagramForge.Diagrams.{Concept, DiagramGenerator}
  alias DiagramForge.Repo

  @impl Oban.Worker
  def perform(%Oban.Job{args: args}) do
    concept_id = args["concept_id"]

    opts =
      if args["ai_client"], do: [ai_client: String.to_existing_atom(args["ai_client"])], else: []

    concept = Repo.get!(Concept, concept_id)

    case DiagramGenerator.generate_for_concept(concept, opts) do
      {:ok, _diagram} -> :ok
      {:error, reason} -> {:error, reason}
    end
  end
end
