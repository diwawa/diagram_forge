defmodule DiagramForge.Diagrams.Document do
  @moduledoc """
  Schema for documents uploaded for diagram generation.

  Tracks document metadata, extraction status, and raw text content.
  """

  use Ecto.Schema
  import Ecto.Changeset

  schema "documents" do
    field :title, :string
    field :source_type, Ecto.Enum, values: [:pdf, :markdown]
    field :path, :string
    field :raw_text, :string

    field :status, Ecto.Enum,
      values: [:uploaded, :processing, :ready, :error],
      default: :uploaded

    field :error_message, :string

    has_many :concepts, DiagramForge.Diagrams.Concept
    has_many :diagrams, DiagramForge.Diagrams.Diagram

    timestamps()
  end

  def changeset(doc, attrs) do
    doc
    |> cast(attrs, [:title, :source_type, :path, :raw_text, :status, :error_message],
      empty_values: []
    )
    |> validate_required([:title, :source_type, :path])
  end
end
