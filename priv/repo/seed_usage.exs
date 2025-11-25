# Script for populating the database with sample API usage data.
# Run via: mix seed.usage
#
# This creates realistic usage data across multiple days, users, and models
# to demonstrate the Usage Dashboard features.

import Ecto.Query
alias DiagramForge.Repo
alias DiagramForge.Accounts.User
alias DiagramForge.Usage
alias DiagramForge.Usage.{AIProvider, AIModel, DailyAggregate, TokenUsage}

IO.puts("Seeding API usage data...")

# ============================================================================
# Ensure AI providers and models exist (run seeds.exs first if needed)
# ============================================================================

openai = Repo.get_by(AIProvider, slug: "openai")

unless openai do
  IO.puts("Error: OpenAI provider not found. Run `mix run priv/repo/seeds.exs` first.")
  System.halt(1)
end

gpt4o_mini = Repo.get_by(AIModel, api_name: "gpt-4o-mini")
gpt4o = Repo.get_by(AIModel, api_name: "gpt-4o")

unless gpt4o_mini do
  IO.puts("Error: GPT-4o-mini model not found. Run `mix run priv/repo/seeds.exs` first.")
  System.halt(1)
end

IO.puts("Using models: #{gpt4o_mini.name}, #{gpt4o && gpt4o.name || "N/A"}")

# ============================================================================
# Clear existing usage data (but keep providers/models/prices)
# ============================================================================

IO.puts("Clearing existing usage data...")
Repo.delete_all(TokenUsage)
Repo.delete_all(DailyAggregate)

# ============================================================================
# Create sample users
# ============================================================================

IO.puts("Creating sample users...")

# Delete any existing seed users first
Repo.delete_all(from u in User, where: u.email in ["alice@example.com", "bob@example.com", "charlie@example.com"])

users =
  for {email, name} <- [
        {"alice@example.com", "Alice Developer"},
        {"bob@example.com", "Bob Engineer"},
        {"charlie@example.com", "Charlie Architect"}
      ] do
    %User{}
    |> User.changeset(%{
      email: email,
      name: name,
      provider: "github",
      provider_uid: "seed_#{String.replace(email, "@example.com", "")}",
      provider_token: "seed_token_#{:rand.uniform(100_000)}",
      show_public_diagrams: true
    })
    |> Repo.insert!()
  end

[alice, bob, charlie] = users
IO.puts("Created #{length(users)} users")

# ============================================================================
# Generate usage data for the past 30 days
# ============================================================================

IO.puts("Generating usage data for the past 30 days...")

today = Date.utc_today()

# Usage patterns per user (to create varied, realistic data)
# {user, model, daily_requests_range, operations}
usage_patterns = [
  # Alice: Heavy user, mostly gpt-4o-mini for diagram generation
  {alice, gpt4o_mini, 15..40, ["diagram_generation", "concept_extraction", "fix_syntax"]},
  # Bob: Moderate user, mix of models
  {bob, gpt4o_mini, 5..20, ["diagram_generation", "concept_extraction"]},
  {bob, gpt4o, 1..5, ["diagram_generation"]},
  # Charlie: Light user, occasional usage
  {charlie, gpt4o_mini, 0..10, ["diagram_generation"]}
]

# Token ranges based on operation type
token_ranges = %{
  "concept_extraction" => {800..2000, 200..500},
  "diagram_generation" => {1000..3000, 300..800},
  "fix_syntax" => {500..1500, 200..400}
}

for day_offset <- 30..0//-1 do
  date = Date.add(today, -day_offset)

  # Skip some weekend days for realism
  day_of_week = Date.day_of_week(date)
  weekend_factor = if day_of_week in [6, 7], do: 0.3, else: 1.0

  for {user, model, request_range, operations} <- usage_patterns do
    # Skip if model doesn't exist (gpt4o might be nil)
    if model do
      # Adjust request count based on day of week
      base_requests = Enum.random(request_range)
      num_requests = round(base_requests * weekend_factor)

      if num_requests > 0 do
        # Generate aggregated data for this user/model/day
        {total_input, total_output} =
          for _ <- 1..num_requests, reduce: {0, 0} do
            {input_acc, output_acc} ->
              operation = Enum.random(operations)
              {input_range, output_range} = token_ranges[operation]
              input_tokens = Enum.random(input_range)
              output_tokens = Enum.random(output_range)
              {input_acc + input_tokens, output_acc + output_tokens}
          end

        # Insert daily aggregate directly (more efficient than individual records)
        Repo.insert!(%DailyAggregate{
          user_id: user.id,
          model_id: model.id,
          date: date,
          request_count: num_requests,
          input_tokens: total_input,
          output_tokens: total_output,
          total_tokens: total_input + total_output,
          cost_cents: 0  # Will be calculated at display time
        })
      end
    end
  end
end

# ============================================================================
# Summary
# ============================================================================

total_aggregates = Repo.aggregate(DailyAggregate, :count, :id)
total_requests = Repo.aggregate(DailyAggregate, :sum, :request_count) || 0
total_input_tokens = Repo.aggregate(DailyAggregate, :sum, :input_tokens) || 0
total_output_tokens = Repo.aggregate(DailyAggregate, :sum, :output_tokens) || 0

# Calculate cost using the new function
summary = Usage.get_summary_for_range(Date.add(today, -30), today)

IO.puts("")
IO.puts("=" |> String.duplicate(50))
IO.puts("Usage Data Seeding Complete!")
IO.puts("=" |> String.duplicate(50))
IO.puts("")
IO.puts("Daily aggregates created: #{total_aggregates}")
IO.puts("Total requests: #{total_requests}")
IO.puts("Total input tokens: #{Number.Delimit.number_to_delimited(total_input_tokens, precision: 0)}")
IO.puts("Total output tokens: #{Number.Delimit.number_to_delimited(total_output_tokens, precision: 0)}")
IO.puts("Estimated cost: $#{Usage.format_cents(summary.cost_cents)}")
IO.puts("")
IO.puts("Users created:")
for user <- users do
  IO.puts("  - #{user.email}")
end
IO.puts("")
IO.puts("View the dashboard at: /admin/usage/dashboard")
