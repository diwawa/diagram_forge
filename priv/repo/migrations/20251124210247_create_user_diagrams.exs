defmodule DiagramForge.Repo.Migrations.CreateUserDiagrams do
  use Ecto.Migration

  def change do
    create table(:user_diagrams, primary_key: false) do
      add :user_id, references(:users, type: :binary_id, on_delete: :delete_all), null: false

      add :diagram_id, references(:diagrams, type: :binary_id, on_delete: :delete_all),
        null: false

      add :is_owner, :boolean, null: false, default: false

      timestamps()
    end

    # Composite primary key ensures one entry per user-diagram pair
    create unique_index(:user_diagrams, [:user_id, :diagram_id])

    # Efficient queries for "my diagrams"
    create index(:user_diagrams, [:user_id])

    # Efficient ownership checks
    create index(:user_diagrams, [:diagram_id])

    # Filter owned vs bookmarked
    create index(:user_diagrams, [:user_id, :is_owner])
  end
end
