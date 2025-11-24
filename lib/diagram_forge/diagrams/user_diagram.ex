defmodule DiagramForge.Diagrams.UserDiagram do
  @moduledoc """
  Join table tracking user-diagram relationships.

  ## Relationship Types

  - `is_owner: true` - User created or forked this diagram (can edit/delete)
  - `is_owner: false` - User bookmarked/saved this diagram (read-only)
  """

  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  @foreign_key_type :binary_id

  schema "user_diagrams" do
    belongs_to :user, DiagramForge.Accounts.User
    belongs_to :diagram, DiagramForge.Diagrams.Diagram

    field :is_owner, :boolean, default: false

    timestamps()
  end

  def changeset(user_diagram, attrs) do
    user_diagram
    |> cast(attrs, [:user_id, :diagram_id, :is_owner])
    |> validate_required([:user_id, :diagram_id, :is_owner])
    |> unique_constraint([:user_id, :diagram_id])
    |> foreign_key_constraint(:user_id)
    |> foreign_key_constraint(:diagram_id)
  end
end
