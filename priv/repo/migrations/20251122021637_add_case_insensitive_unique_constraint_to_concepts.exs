defmodule DiagramForge.Repo.Migrations.AddCaseInsensitiveUniqueConstraintToConcepts do
  use Ecto.Migration

  def up do
    # Step 1: Deduplicate case variants (e.g., "GenServer", "genserver", "GENSERVER")
    # Keep the one with most diagrams, or if tied, the oldest one
    execute """
    WITH case_duplicates AS (
      SELECT
        LOWER(name) as lower_name,
        array_agg(id ORDER BY
          (SELECT COUNT(*) FROM diagrams WHERE diagrams.concept_id = concepts.id) DESC,
          inserted_at ASC
        ) as concept_ids
      FROM concepts
      GROUP BY LOWER(name)
      HAVING COUNT(*) > 1
    ),
    concepts_to_keep AS (
      SELECT
        lower_name,
        concept_ids[1] as keep_id,
        concept_ids[2:array_length(concept_ids, 1)] as delete_ids
      FROM case_duplicates
    ),
    -- Update diagrams to point to the concept we're keeping
    updated_diagrams AS (
      UPDATE diagrams
      SET concept_id = (
        SELECT keep_id
        FROM concepts_to_keep
        WHERE diagrams.concept_id = ANY(delete_ids)
        LIMIT 1
      )
      WHERE concept_id IN (
        SELECT unnest(delete_ids)
        FROM concepts_to_keep
      )
      RETURNING id
    )
    -- Delete duplicate concepts
    DELETE FROM concepts
    WHERE id IN (
      SELECT unnest(delete_ids)
      FROM concepts_to_keep
    );
    """

    # Step 2: Drop the case-sensitive unique index
    drop_if_exists index(:concepts, [:name])

    # Step 3: Create a case-insensitive unique index using LOWER()
    execute "CREATE UNIQUE INDEX concepts_lower_name_index ON concepts (LOWER(name))"
  end

  def down do
    # Revert: Drop case-insensitive index, add back case-sensitive one
    execute "DROP INDEX IF EXISTS concepts_lower_name_index"
    create unique_index(:concepts, [:name])
  end
end
