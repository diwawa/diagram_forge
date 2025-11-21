defmodule DiagramForge.Diagrams.Concept do
  @moduledoc """
  Schema for technical concepts extracted from documents.

  Concepts represent key technical ideas identified by LLM analysis
  that are suitable for visualization in diagrams.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "concepts" do
    belongs_to :document, DiagramForge.Diagrams.Document

    field :name, :string
    field :short_description, :string
    field :category, :string
    field :level, Ecto.Enum, values: [:beginner, :intermediate, :advanced], default: :beginner
    field :importance, :integer, default: 3

    has_many :diagrams, DiagramForge.Diagrams.Diagram

    timestamps()
  end

  def changeset(concept, attrs) do
    concept
    |> cast(attrs, [:document_id, :name, :short_description, :category, :level, :importance])
    |> validate_required([:name, :category])
    |> validate_number(:importance, greater_than_or_equal_to: 1, less_than_or_equal_to: 5)
  end
end
