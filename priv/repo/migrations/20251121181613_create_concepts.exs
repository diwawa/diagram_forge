defmodule DiagramForge.Repo.Migrations.CreateConcepts do
  use Ecto.Migration

  def change do
    create table(:concepts) do
      add :document_id, references(:documents, on_delete: :delete_all), null: false
      add :name, :string, null: false
      add :short_description, :text
      add :category, :string, null: false
      add :level, :string, null: false, default: "beginner"
      add :importance, :integer, default: 3

      timestamps()
    end

    create index(:concepts, [:document_id, :name])
    create index(:concepts, [:document_id])
  end
end
