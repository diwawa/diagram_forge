defmodule DiagramForge.AI.Prompts do
  @moduledoc """
  Prompt templates for AI-powered concept extraction and diagram generation.
  """

  @concept_system_prompt """
  You are a technical teaching assistant.

  Given an excerpt from a technical document, identify the most important concepts that would be useful to explain visually in a diagram.

  Focus on:
  - architecture and components
  - data flow and message flow
  - lifecycles and state transitions
  - interactions between services or modules

  Only output strictly valid JSON. Do not include any explanation outside the JSON object.
  """

  @diagram_system_prompt """
  You generate small, interview-friendly technical diagrams in Mermaid syntax.

  Constraints:
  - The diagram must fit on a single screen and stay readable.
  - Use at most 10 nodes and 15 edges.
  - Prefer 'flowchart' or 'sequenceDiagram' unless another type is clearly better.
  - Use concise labels, avoid sentences on nodes.
  - Only output strictly valid JSON with the requested fields.
  """

  @doc """
  Returns the system prompt for concept extraction.
  """
  def concept_system_prompt, do: @concept_system_prompt

  @doc """
  Returns the user prompt for concept extraction from a text chunk.

  ## Examples

      iex> DiagramForge.AI.Prompts.concept_user_prompt("some text")
      \"\"\"
      Text:
      ```text
      some text
      ```

      Return JSON in this exact structure:

      {
        "concepts": [
          {
            "name": "short name for the concept",
            "short_description": "1–2 sentence description suitable for learners or interview prep.",
            "category": "elixir | phoenix | http | kafka | llm | agents | other"
          }
        ]
      }

      Do not mention the JSON format in your response. Just output JSON.
      \"\"\"

  """
  def concept_user_prompt(text) do
    """
    Text:
    ```text
    #{text}
    ```

    Return JSON in this exact structure:

    {
      "concepts": [
        {
          "name": "short name for the concept",
          "short_description": "1–2 sentence description suitable for learners or interview prep.",
          "category": "elixir | phoenix | http | kafka | llm | agents | other"
        }
      ]
    }

    Do not mention the JSON format in your response. Just output JSON.
    """
  end

  @doc """
  Returns the system prompt for diagram generation.
  """
  def diagram_system_prompt, do: @diagram_system_prompt

  @doc """
  Returns the user prompt for generating a diagram from a concept with context.

  ## Examples

      iex> concept = %{name: "GenServer", category: "elixir", level: :intermediate, short_description: "OTP behavior"}
      iex> DiagramForge.AI.Prompts.diagram_from_concept_user_prompt(concept, "some context")
      # Returns a formatted prompt string

  """
  def diagram_from_concept_user_prompt(concept, context_excerpt) do
    """
    Create a Mermaid diagram for this concept:

    Name: #{concept.name}
    Category: #{concept.category}
    Short description: #{concept.short_description}

    Context from the source document (optional, you may ignore irrelevant parts):
    ```text
    #{context_excerpt}
    ```

    Return JSON like:

    {
      "title": "Readable title for the diagram",
      "domain": "elixir | phoenix | http | kafka | llm | agents | other",
      "tags": ["list", "of", "short", "tags"],
      "mermaid": "mermaid code here (flowchart or sequenceDiagram, escaped as needed)",
      "summary": "1–2 sentence explanation of what the diagram shows.",
      "notes_md": "- bullet point explanation in markdown\\n- keep it concise"
    }

    Do not include markdown fences around the mermaid code.
    Do not include any explanation outside the JSON object.
    """
  end

  @doc """
  Returns the user prompt for generating a diagram from a free-form text prompt.

  ## Examples

      iex> DiagramForge.AI.Prompts.diagram_from_prompt_user_prompt("Create a diagram about how tokenization works")
      # Returns a formatted prompt string

  """
  def diagram_from_prompt_user_prompt(text) do
    """
    The user wants a small technical diagram based on this description:

    "#{text}"

    Assume the reader is a curious developer preparing for interviews.

    Follow the same JSON structure as before:

    {
      "title": "...",
      "domain": "elixir | phoenix | http | kafka | llm | agents | other",
      "tags": ["...", "..."],
      "mermaid": "mermaid code here",
      "summary": "...",
      "notes_md": "markdown bullets..."
    }

    Choose domain based on the description.
    Only output JSON.
    """
  end
end
