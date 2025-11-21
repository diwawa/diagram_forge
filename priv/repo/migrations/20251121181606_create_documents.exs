defmodule DiagramForge.Repo.Migrations.CreateDocuments do
  use Ecto.Migration

  def change do
    create table(:documents) do
      add :title, :string, null: false
      add :source_type, :string, null: false
      add :path, :string, null: false
      add :raw_text, :text
      add :status, :string, null: false, default: "uploaded"
      add :error_message, :text

      timestamps()
    end

    create index(:documents, [:status])
  end
end
