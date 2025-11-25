# Content Moderation Implementation

## Overview

DiagramForge allows users to create and publicly share diagrams. To prevent abuse (spam, inappropriate content, self-promotion), we need a content moderation system that balances user experience with platform safety.

## Goals

1. **Prevent hostile/abusive/pornographic/political content** from being publicly visible
2. **Block spam and self-promotion** (URLs, promotional text)
3. **Maintain SEO-friendly public diagrams** - we want Google indexing, just not for problematic content
4. **Minimize false positives** - don't block legitimate technical diagrams

## Threat Model

### What We're Protecting Against

| Threat | Risk Level | Mitigation |
|--------|------------|------------|
| Pornographic/explicit content | High | AI moderation before publish |
| Political propaganda | Medium | AI moderation + manual review queue |
| Hate speech/harassment | High | AI moderation before publish |
| Spam URLs in diagram text | Medium | URL stripping/validation |
| HTML injection in labels | Low | Text sanitization |
| SEO spam (keyword stuffing) | Medium | AI moderation |

### What We're NOT Concerned About

- User profiles (we don't have them)
- Comments/social features (we don't have them)
- Direct messaging (we don't have it)

## Implementation Phases

### Phase 1: Input Sanitization (Essential)

**Goal**: Prevent HTML/script injection and remove URLs from diagram content.

#### 1.1 Text Sanitization

Strip HTML tags from all user-provided text fields:

```elixir
defmodule DiagramForge.Content.Sanitizer do
  @moduledoc """
  Sanitizes user-provided content to prevent injection attacks.
  """

  @doc """
  Strips HTML tags from text, preserving only plain text content.
  """
  def strip_html(nil), do: nil
  def strip_html(text) when is_binary(text) do
    text
    |> HtmlSanitizeEx.strip_tags()
    |> String.trim()
  end

  @doc """
  Removes URLs from text content.
  Returns {sanitized_text, removed_urls}.
  """
  def strip_urls(nil), do: {nil, []}
  def strip_urls(text) when is_binary(text) do
    url_pattern = ~r{https?://[^\s<>"{}|\\^`\[\]]+}i
    urls = Regex.scan(url_pattern, text) |> List.flatten()
    sanitized = Regex.replace(url_pattern, text, "[link removed]")
    {sanitized, urls}
  end

  @doc """
  Full sanitization pipeline for diagram content.
  """
  def sanitize_diagram_content(text) do
    text
    |> strip_html()
    |> strip_urls()
    |> elem(0)
  end
end
```

#### 1.2 Apply Sanitization Points

Apply sanitization at these points:
- Diagram title (on save)
- Diagram description (on save)
- Mermaid source code node labels (on save)
- Any AI-generated content before display

#### 1.3 Mermaid-Specific Sanitization

Disable dangerous Mermaid directives:

```elixir
defmodule DiagramForge.Content.MermaidSanitizer do
  @moduledoc """
  Sanitizes Mermaid diagram source code.
  """

  # Directives that allow script execution or external links
  @dangerous_directives [
    ~r/click\s+\w+\s+(?:href|call)/i,  # click handlers with href/call
    ~r/%%\s*\{.*\}%%/,                   # JSON config blocks (can enable scripts)
  ]

  def sanitize(source) do
    Enum.reduce(@dangerous_directives, source, fn pattern, acc ->
      Regex.replace(pattern, acc, "")
    end)
  end
end
```

### Phase 2: AI Content Moderation (Pre-Publish)

**Goal**: Use AI to detect inappropriate content before it becomes publicly visible.

#### 2.1 Moderation States

Add a moderation status to diagrams:

```elixir
# Migration: add_moderation_to_diagrams
alter table(:diagrams) do
  add :moderation_status, :string, default: "pending"  # pending, approved, rejected, manual_review
  add :moderation_reason, :text
  add :moderated_at, :utc_datetime
end

create index(:diagrams, [:moderation_status])
```

#### 2.2 Visibility Rules

```elixir
# In Diagram schema or context
def publicly_visible?(diagram) do
  diagram.is_public and diagram.moderation_status == "approved"
end
```

#### 2.3 AI Moderation Service

```elixir
defmodule DiagramForge.Content.Moderator do
  @moduledoc """
  AI-powered content moderation for diagrams.
  """

  alias DiagramForge.AI.Client

  @moderation_prompt """
  You are a content moderator for a technical diagram creation platform.

  Analyze the following diagram content and determine if it violates our policies.

  POLICIES:
  - No pornographic, sexually explicit, or NSFW content
  - No hate speech, harassment, or discriminatory content
  - No political propaganda or election-related misinformation
  - No violent or threatening content
  - No spam, advertising, or promotional content
  - No illegal content

  Technical diagrams about: software architecture, databases, workflows,
  org charts, flowcharts, etc. are ALLOWED even if they mention sensitive
  topics in an educational/professional context.

  DIAGRAM CONTENT:
  Title: {title}
  Description: {description}
  Diagram Type: {type}
  Source:
  {source}

  Respond with JSON only:
  {
    "decision": "approve" | "reject" | "manual_review",
    "confidence": 0.0-1.0,
    "reason": "brief explanation",
    "flags": ["category1", "category2"]
  }
  """

  @doc """
  Moderates diagram content using AI.
  Returns {:ok, result} or {:error, reason}.
  """
  def moderate(%Diagram{} = diagram) do
    prompt = @moderation_prompt
    |> String.replace("{title}", diagram.title || "")
    |> String.replace("{description}", diagram.description || "")
    |> String.replace("{type}", to_string(diagram.type))
    |> String.replace("{source}", diagram.source || "")

    case Client.chat!([%{role: "user", content: prompt}],
           operation: "content_moderation",
           track_usage: true) do
      response when is_binary(response) ->
        parse_moderation_response(response)
      error ->
        {:error, "Moderation failed: #{inspect(error)}"}
    end
  end

  defp parse_moderation_response(response) do
    case Jason.decode(response) do
      {:ok, %{"decision" => decision} = result} when decision in ~w(approve reject manual_review) ->
        {:ok, result}
      {:ok, _} ->
        {:error, "Invalid moderation response format"}
      {:error, _} ->
        {:error, "Failed to parse moderation response"}
    end
  end
end
```

#### 2.4 Moderation Workflow

```elixir
defmodule DiagramForge.Content.ModerationWorkflow do
  @moduledoc """
  Handles the moderation workflow for diagrams.
  """

  alias DiagramForge.Content.Moderator
  alias DiagramForge.Diagrams
  alias DiagramForge.Diagrams.Diagram

  @doc """
  Called when a diagram is made public or content is updated.
  """
  def moderate_diagram(%Diagram{} = diagram) do
    case Moderator.moderate(diagram) do
      {:ok, %{"decision" => "approve", "confidence" => confidence}} when confidence >= 0.8 ->
        Diagrams.update_moderation_status(diagram, "approved", "Auto-approved by AI")

      {:ok, %{"decision" => "reject", "reason" => reason}} ->
        Diagrams.update_moderation_status(diagram, "rejected", reason)
        # Optionally: revert to private, notify user

      {:ok, %{"decision" => "manual_review", "reason" => reason}} ->
        Diagrams.update_moderation_status(diagram, "manual_review", reason)
        # Queue for admin review

      {:ok, %{"decision" => "approve"}} ->
        # Low confidence approval - queue for review but allow
        Diagrams.update_moderation_status(diagram, "manual_review", "Low confidence approval")

      {:error, reason} ->
        # On error, queue for manual review rather than blocking
        Diagrams.update_moderation_status(diagram, "manual_review", "Moderation error: #{reason}")
    end
  end
end
```

### Phase 3: Admin Moderation Queue

**Goal**: Allow admins to review flagged content and make final decisions.

#### 3.1 Admin Queue Page

Create a Backpex resource or LiveView for the moderation queue:

- List diagrams with `moderation_status: "manual_review"`
- Show diagram preview, AI reasoning, and flags
- Actions: Approve, Reject (with reason), Ban User

#### 3.2 Moderation Actions

```elixir
defmodule DiagramForge.Content.AdminActions do
  def approve_diagram(diagram, admin) do
    Diagrams.update_moderation_status(diagram, "approved", "Manually approved by #{admin.email}")
  end

  def reject_diagram(diagram, admin, reason) do
    Diagrams.update_moderation_status(diagram, "rejected", reason)
    # Make diagram private
    Diagrams.update_diagram(diagram, %{is_public: false})
    # Optionally notify user
  end

  def ban_user(user, admin, reason) do
    # Future: implement user banning
  end
end
```

### Phase 4: Rate Limiting & Abuse Prevention

**Goal**: Prevent automated abuse and spam attacks.

#### 4.1 Rate Limits

```elixir
# In router or plug
plug DiagramForge.RateLimiter,
  limits: [
    # Per user
    {"/api/diagrams", :user, 10, :minute},      # 10 diagrams per minute
    {"/api/diagrams", :user, 100, :day},        # 100 diagrams per day

    # Per IP (for unauthenticated)
    {"/api/diagrams", :ip, 5, :minute}
  ]
```

#### 4.2 Suspicious Activity Detection

Track and flag:
- Users creating many public diagrams rapidly
- Users with high rejection rates
- Users repeatedly editing rejected diagrams
- Similar content across multiple diagrams (template spam)

## Cost Considerations

### AI Moderation Costs

Using gpt-4o-mini for moderation:
- ~500 tokens per moderation request
- At $0.15/1M input + $0.60/1M output
- Estimated cost: ~$0.0005 per diagram moderation

**Cost mitigation strategies:**
1. Only moderate when diagram becomes public
2. Cache moderation results (re-moderate only on content change)
3. Use text similarity to skip re-moderation of minor changes
4. Batch moderation for bulk operations

### Projected Costs

| Monthly Public Diagrams | Moderation Cost |
|------------------------|-----------------|
| 100 | ~$0.05 |
| 1,000 | ~$0.50 |
| 10,000 | ~$5.00 |
| 100,000 | ~$50.00 |

## Implementation Priority

### Immediate (Phase 1)
- [ ] Create `DiagramForge.Content.Sanitizer` module
- [ ] Apply HTML stripping to diagram title/description
- [ ] Apply URL stripping to diagram content
- [ ] Add Mermaid directive sanitization

### Short-term (Phase 2)
- [ ] Add `moderation_status` to diagrams schema
- [ ] Create `DiagramForge.Content.Moderator` module
- [ ] Integrate moderation into publish workflow
- [ ] Add moderation cost tracking to usage system

### Medium-term (Phase 3)
- [ ] Create admin moderation queue UI
- [ ] Implement admin moderation actions
- [ ] Add moderation audit logging
- [ ] User notification system for rejections

### Future (Phase 4)
- [ ] Rate limiting implementation
- [ ] Suspicious activity detection
- [ ] User reputation system
- [ ] Appeal process for rejected content

## Configuration

```elixir
# config/config.exs
config :diagram_forge, DiagramForge.Content,
  moderation_enabled: true,
  auto_approve_threshold: 0.8,
  moderate_on_publish: true,
  strip_urls: true,
  strip_html: true

# config/dev.exs - disable in development
config :diagram_forge, DiagramForge.Content,
  moderation_enabled: false

# config/test.exs - mock moderation in tests
config :diagram_forge, DiagramForge.Content,
  moderation_enabled: false
```

## Database Schema Summary

```sql
-- Add to diagrams table
ALTER TABLE diagrams ADD COLUMN moderation_status VARCHAR DEFAULT 'pending';
ALTER TABLE diagrams ADD COLUMN moderation_reason TEXT;
ALTER TABLE diagrams ADD COLUMN moderated_at TIMESTAMP;
CREATE INDEX idx_diagrams_moderation ON diagrams(moderation_status);

-- Moderation audit log (optional)
CREATE TABLE moderation_logs (
  id UUID PRIMARY KEY,
  diagram_id UUID REFERENCES diagrams(id),
  action VARCHAR NOT NULL,  -- 'ai_approve', 'ai_reject', 'admin_approve', 'admin_reject'
  reason TEXT,
  performed_by UUID REFERENCES users(id),  -- NULL for AI actions
  ai_confidence DECIMAL,
  ai_flags TEXT[],
  inserted_at TIMESTAMP NOT NULL
);
```

## Success Metrics

- **False positive rate**: < 1% of legitimate diagrams incorrectly flagged
- **False negative rate**: < 0.1% of policy-violating content published
- **Moderation latency**: < 3 seconds for AI moderation
- **Admin queue size**: < 50 items requiring manual review per day
- **Cost per diagram**: < $0.001 average moderation cost
