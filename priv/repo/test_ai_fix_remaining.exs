# Test AI fix on the 6 still-broken diagrams (after first round)
# Run with: mix run priv/repo/test_ai_fix_remaining.exs

alias DiagramForge.Repo
alias DiagramForge.Diagrams
alias DiagramForge.Diagrams.Diagram
import Ecto.Query

# Get the admin user for usage tracking
admin_email = System.get_env("DF_SUPERADMIN_USER") || "seed@example.com"
admin_user = Repo.get_by!(DiagramForge.Accounts.User, email: admin_email)

# The 6 still-broken diagram IDs (from first round of testing)
still_broken_ids = [
  "83f71de0-378b-4e31-a59f-6a07559f0cfc",  # Elixir Sigils Implementation - escaped \n
  "05f73396-20ba-44ca-b5d9-5a7105a8e6fe",  # Data Formatting Process - escaped quotes in array
  "e2f5824b-b4b5-4856-8a41-44cdf69906ea",  # Enum Operations - nested quotes
  "5a03c017-1ad1-4fa8-813d-fac7d3d6d991",  # Elixir Mix Project - unquoted with quotes
  "8fe16104-7a0e-41b9-a197-46b21bc1c69e",  # List Module Functions - complex nested quotes
  "b81a1ed6-b6d8-4d48-9977-5c5740054162"   # Elixir Data Types - escaped quotes in edge
]

IO.puts("\n=== Testing AI Fix on #{length(still_broken_ids)} Still-Broken Diagrams ===\n")

# Fetch diagrams
diagrams =
  from(d in Diagram, where: d.id in ^still_broken_ids)
  |> Repo.all()

IO.puts("Found #{length(diagrams)} diagrams in database\n")

results = %{fixed: [], failed: [], unchanged: []}

results =
  Enum.reduce(Enum.with_index(still_broken_ids, 1), results, fn {id, idx}, acc ->
    IO.puts("--- #{idx}/#{length(still_broken_ids)}: #{id} ---")

    case Enum.find(diagrams, &(&1.id == id)) do
      nil ->
        IO.puts("  NOT FOUND")
        acc

      diagram ->
        IO.puts("  Title: #{diagram.title}")

        case Diagrams.fix_diagram_syntax_source(
               diagram.diagram_source,
               diagram.summary,
               user_id: admin_user.id,
               skip_sanitizer: true,
               max_retries: 2
             ) do
          {:ok, fixed_source} ->
            if fixed_source == diagram.diagram_source do
              IO.puts("  UNCHANGED")
              %{acc | unchanged: [{id, diagram.title, fixed_source} | acc.unchanged]}
            else
              IO.puts("  FIXED - checking for escaped quotes...")
              has_escaped = String.contains?(fixed_source, "\\\"") or String.contains?(fixed_source, "\\'")
              if has_escaped do
                IO.puts("  WARNING: Still contains escaped quotes!")
              end
              %{acc | fixed: [{id, diagram.title, fixed_source} | acc.fixed]}
            end

          {:error, reason} ->
            IO.puts("  FAILED - #{inspect(reason)}")
            %{acc | failed: [{id, diagram.title, reason} | acc.failed]}
        end
    end
  end)

IO.puts("\n\n=== RESULTS ===")
IO.puts("Fixed: #{length(results.fixed)}")
IO.puts("Failed: #{length(results.failed)}")
IO.puts("Unchanged: #{length(results.unchanged)}")

# Write fixed diagrams for validation
if length(results.fixed) > 0 do
  fixed_for_validation =
    Enum.map(results.fixed, fn {id, title, source} ->
      %{id: id, title: title, source: source}
    end)

  File.write!("/tmp/fixed_diagrams_round2.json", Jason.encode!(fixed_for_validation, pretty: true))
  IO.puts("\nFixed diagrams written to /tmp/fixed_diagrams_round2.json")

  # Also show the fixed source for inspection
  IO.puts("\n=== FIXED SOURCES ===")
  for {id, title, source} <- Enum.reverse(results.fixed) do
    IO.puts("\n--- #{title} (#{id}) ---")
    IO.puts(source)
  end
end

IO.puts("\nDone!")
