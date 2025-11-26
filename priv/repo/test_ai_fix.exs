# Test AI fix on all 16 broken diagrams
# Run with: mix run priv/repo/test_ai_fix.exs

alias DiagramForge.Repo
alias DiagramForge.Diagrams
alias DiagramForge.Diagrams.Diagram
import Ecto.Query

# Get the admin user for usage tracking
admin_email = System.get_env("DF_SUPERADMIN_USER") || "seed@example.com"
admin_user = Repo.get_by!(DiagramForge.Accounts.User, email: admin_email)

# The 16 broken diagram IDs
broken_ids = [
  "fecf898c-54fe-4b37-98ad-3f0117c5f0ae",  # 1. Invalid -->> arrow
  "4c763f11-bb40-42a7-975e-f24d32572460",  # 2. Escaped parentheses
  "b81a1ed6-b6d8-4d48-9977-5c5740054162",  # 3. Nested quotes with colon
  "8fe16104-7a0e-41b9-a197-46b21bc1c69e",  # 4. Mismatched brackets "]]
  "0300fb24-cfea-42ec-b46b-2f052f99ea73",  # 5. Truncated diagram
  "5a03c017-1ad1-4fa8-813d-fac7d3d6d991",  # 6. Unquoted node with quotes
  "e2f5824b-b4b5-4856-8a41-44cdf69906ea",  # 7. Nested quotes in edge label
  "05f73396-20ba-44ca-b5d9-5a7105a8e6fe",  # 8. Nested quotes in node label
  "83f71de0-378b-4e31-a59f-6a07559f0cfc",  # 9. Unquoted parentheses
  "4c975554-47fc-41b7-bd84-63555b36ad12",  # 10. Mismatched brackets "}
  "cc4ec3f9-def5-4f7e-bc5b-02d3b5cc6068",  # 11. Mismatched brackets
  "4f56b8c1-269b-4101-8d2e-266882ce8a92",  # 12. Nested quotes
  "a8736352-e8b9-4566-870c-332e8ead7c6c",  # 13. Unclosed quotes
  "62d8fff7-f14e-4181-8fa1-f2ef7ec5ff87",  # 14. Truncated diagram
  "2cdd0b2f-647f-47d1-be59-dccc9edf6997",  # 15. Unquoted @ symbol
  "1ea72d71-5781-467e-85bf-7752f18a2da4"   # 16. Nested quotes with colon
]

IO.puts("\n=== Testing AI Fix on #{length(broken_ids)} Broken Diagrams ===\n")

# Fetch all broken diagrams
diagrams =
  from(d in Diagram, where: d.id in ^broken_ids)
  |> Repo.all()

IO.puts("Found #{length(diagrams)} diagrams in database\n")

# Results tracking
results = %{
  fixed: [],
  failed: [],
  not_found: [],
  unchanged: []
}

# Process each diagram
results =
  Enum.reduce(Enum.with_index(broken_ids, 1), results, fn {id, idx}, acc ->
    IO.puts("--- #{idx}/#{length(broken_ids)}: #{id} ---")

    case Enum.find(diagrams, &(&1.id == id)) do
      nil ->
        IO.puts("  NOT FOUND in database")
        %{acc | not_found: [id | acc.not_found]}

      diagram ->
        IO.puts("  Title: #{diagram.title}")
        IO.puts("  Original source length: #{String.length(diagram.diagram_source)} chars")

        # Try AI fix (skip sanitizer to force AI)
        case Diagrams.fix_diagram_syntax_source(
               diagram.diagram_source,
               diagram.summary,
               user_id: admin_user.id,
               skip_sanitizer: true,
               max_retries: 2
             ) do
          {:ok, fixed_source} ->
            if fixed_source == diagram.diagram_source do
              IO.puts("  UNCHANGED - AI returned same code")
              %{acc | unchanged: [{id, diagram.title, fixed_source} | acc.unchanged]}
            else
              IO.puts("  FIXED - New source length: #{String.length(fixed_source)} chars")
              %{acc | fixed: [{id, diagram.title, fixed_source} | acc.fixed]}
            end

          {:error, reason} ->
            IO.puts("  FAILED - #{inspect(reason)}")
            %{acc | failed: [{id, diagram.title, reason} | acc.failed]}
        end
    end
  end)

IO.puts("\n\n=== RESULTS SUMMARY ===")
IO.puts("Fixed: #{length(results.fixed)}")
IO.puts("Failed: #{length(results.failed)}")
IO.puts("Unchanged: #{length(results.unchanged)}")
IO.puts("Not Found: #{length(results.not_found)}")

# Write fixed diagrams to JSON for validation
if length(results.fixed) > 0 do
  fixed_for_validation =
    Enum.map(results.fixed, fn {id, title, source} ->
      %{id: id, title: title, source: source}
    end)

  File.write!("/tmp/fixed_diagrams_for_validation.json", Jason.encode!(fixed_for_validation, pretty: true))
  IO.puts("\nFixed diagrams written to /tmp/fixed_diagrams_for_validation.json")
  IO.puts("Run validation with: cd assets && node validate_fixed.mjs")
end

# Show details of failed/unchanged
if length(results.failed) > 0 do
  IO.puts("\n=== FAILED DIAGRAMS ===")
  for {id, title, reason} <- Enum.reverse(results.failed) do
    IO.puts("- #{title} (#{id}): #{inspect(reason)}")
  end
end

if length(results.unchanged) > 0 do
  IO.puts("\n=== UNCHANGED DIAGRAMS ===")
  for {id, title, _source} <- Enum.reverse(results.unchanged) do
    IO.puts("- #{title} (#{id})")
  end
end

IO.puts("\nDone!")
