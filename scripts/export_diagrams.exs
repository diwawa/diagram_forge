# Export diagrams for backup and validation
# Run with: mix run scripts/export_diagrams.exs
#
# Two modes:
#   Default (full export): Exports all fields for backup/restore via mix import.diagrams
#   Validation mode: OUTPUT_FILE=/tmp/diagrams_to_validate.json mix run scripts/export_diagrams.exs --validate
#
# Full export goes to /tmp/diagrams_export.json
# Validation export goes to /tmp/diagrams_to_validate.json

alias DiagramForge.Repo
alias DiagramForge.Diagrams.Diagram

validation_mode = "--validate" in System.argv()

output_file =
  if validation_mode do
    System.get_env("OUTPUT_FILE") || "/tmp/diagrams_to_validate.json"
  else
    System.get_env("OUTPUT_FILE") || "/tmp/diagrams_export.json"
  end

diagrams = Repo.all(Diagram)

export_data =
  if validation_mode do
    # Minimal export for mermaid syntax validation
    Enum.map(diagrams, fn d ->
      %{
        id: d.id,
        title: d.title,
        source: d.diagram_source
      }
    end)
  else
    # Full export for backup/restore
    %{
      exported_at: DateTime.utc_now() |> DateTime.to_iso8601(),
      diagrams: Enum.map(diagrams, fn d ->
        %{
          title: d.title,
          tags: d.tags,
          diagram_source: d.diagram_source,
          summary: d.summary,
          notes_md: d.notes_md,
          visibility: to_string(d.visibility),
          format: to_string(d.format)
        }
      end)
    }
  end

json = Jason.encode!(export_data, pretty: true)
File.write!(output_file, json)

mode_label = if validation_mode, do: "validation", else: "full backup"
IO.puts("Exported #{length(diagrams)} diagrams (#{mode_label}) to #{output_file}")
