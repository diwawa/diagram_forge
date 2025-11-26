defmodule DiagramForge.AI.Prompts do
  @moduledoc """
  Prompt templates for AI-powered concept extraction and diagram generation.

  These are default prompts. Database-stored prompts (via admin) take precedence
  when available.
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

  # Mermaid version from package.json (used in prompts for version-specific syntax)
  @mermaid_version "11.12.1"

  @diagram_system_prompt """
  You generate small, interview-friendly technical diagrams in Mermaid syntax.
  Target Mermaid version: #{@mermaid_version}

  Constraints:
  - The diagram must fit on a single screen and stay readable.
  - Use at most 10 nodes and 15 edges.
  - Prefer 'flowchart' or 'sequenceDiagram' unless another type is clearly better.
  - Use concise labels, avoid sentences on nodes.

  CRITICAL Mermaid syntax rules - ALWAYS quote labels with special characters:

  Node labels with ANY of these MUST be quoted with double quotes:
  - Parentheses: A["process(file)"] not A[process(file)]
  - Dots: A["File.open"] not A[File.open]
  - Exclamation marks: A["File.open!"] not A[File.open!]
  - Colons: A["key: value"] not A[key: value]
  - Curly braces: NEVER use {} in node labels, they define shapes

  Edge labels with special chars MUST be quoted:
  - -->|"{:ok, pid}"| not -->|{:ok, pid}|
  - -->|"error: msg"| not -->|error: msg|

  AVOID nested quotes - simplify instead:
  - A[raise error] not A[raise "error"]

  When in doubt, QUOTE the label or simplify the text.

  Only output strictly valid JSON with the requested fields.
  """

  # Template uses {{MERMAID_CODE}}, {{SUMMARY}}, and {{ERROR_CONTEXT}} placeholders
  @fix_mermaid_syntax_prompt """
  The following Mermaid diagram has a syntax error and won't render:

  ```mermaid
  {{MERMAID_CODE}}
  ```

  Context about what this diagram should show:
  {{SUMMARY}}
  {{ERROR_CONTEXT}}

  SCAN EVERY NODE AND EDGE LABEL for these issues:

  1. PARENTHESES in node labels - MUST be quoted or removed:
     WRONG: B[process(file)]  or  A[func(arg)]
     RIGHT: B["process(file)"]  or  B[process file]  or  A["func(arg)"]

  2. EDGE LABELS WITH SPECIAL CHARS - MUST be quoted in Mermaid 11.x:
     WRONG: -->|{:ok, pid}|  or  -->|[1,2,3]|  or  -->|func(arg)|
     RIGHT: -->|"{:ok, pid}"|  or  -->|"[1,2,3]"|  or  -->|"func(arg)"|
     ANY edge label containing { } [ ] ( ) MUST be wrapped in quotes: |"..."|

  3. DOTS in node labels - safer to quote:
     WRONG: A[File.open]  or  C[IO.puts]
     RIGHT: A["File.open"]  or  C["IO.puts"]

  4. EXCLAMATION MARKS - must be quoted:
     WRONG: F[File.open!]
     RIGHT: F["File.open!"]

  5. NESTED QUOTES - remove inner quotes:
     WRONG: A[raise "error"]
     RIGHT: A[raise error]  or  A["raise error"]

  6. COLONS, PIPES, and other special chars need quotes:
     WRONG: A[key: value]
     RIGHT: A["key: value"]

  7. MISMATCHED BRACKETS - opening and closing must match:
     WRONG: A["label']  or  B["text}  or  C['value"]
     RIGHT: A["label"]  or  B["text"]  or  C["value"]
     Check that [ matches ], " matches ", ' matches '

  8. INVALID ARROW SYNTAX - use only valid Mermaid arrows:
     WRONG: A -->> B  or  A ==> B  or  A ~~> B
     RIGHT: A --> B  or  A ---> B  or  A -.-> B  or  A ==> B (subgraph only)
     Valid arrows: -->, --->, -.->, -.-, ==>, <-->, ---|text|

  9. MIXED QUOTE TYPES - don't mix " and ' in the same label:
     WRONG: A["it's here']  or  B['say "hello"']
     RIGHT: A["its here"]  or  B["say hello"]  or  A["it is here"]

  10. NO ESCAPED QUOTES - Mermaid CANNOT have \" or \' inside labels:
      WRONG: A["say \"hello\""]  or  B["it\'s here"]  or  |"colors[\"red\"]"|
      RIGHT: A["say hello"]  or  B["its here"]  or  |"colors red"|
      CRITICAL: Remove ALL backslash escapes. Simplify text to avoid inner quotes entirely.
      If a label needs quotes inside, REMOVE them or describe the content differently.

  11. ESCAPED PARENTHESES - remove backslash escapes:
      WRONG: A["File.open\\(file\\)"]  or  B["func\\(arg\\)"]
      RIGHT: A["File.open(file)"]  or  B["func(arg)"]
      Mermaid doesn't use backslash escapes - just quote the label properly

  12. UNQUOTED @ SYMBOL - @ must be quoted in node labels:
      WRONG: A[@spec]  or  B[@type]  or  C[@doc]
      RIGHT: A["@spec"]  or  B["@type"]  or  C["@doc"]

  13. UNCLOSED OR MISSING QUOTES - every quote must have a matching close:
      WRONG: E["IO.puts 'End of macro]  or  F["some text]
      RIGHT: E["IO.puts End of macro"]  or  F["some text"]
      If a label has opening quotes, ensure closing quotes exist

  14. TRUNCATED OR INCOMPLETE NODES - if a diagram ends mid-node, complete it:
      WRONG: A[  (incomplete)  or  K["{  (truncated)
      RIGHT: A["placeholder"]  or  remove the incomplete node entirely
      If impossible to fix, remove the broken node/edge

  15. NESTED QUOTES WITH SPECIAL CHARS - simplify labels with inner quotes AND colons:
      WRONG: G["@color_map[\":hsb\"]"]  or  A["colors[\":red\"]"]
      RIGHT: G["@color_map hsb"]  or  A["colors red"]
      When quotes appear inside already-quoted labels, remove inner quotes and simplify

  16. DOUBLE BRACKETS OR BRACES - remove duplicate closings:
      WRONG: B["Result: [1, 2, 3"]]  or  I["result"}
      RIGHT: B["Result: 1, 2, 3"]  or  I["result"]
      A node cannot have ]] or "} - simplify content and use single closing

  17. HTML ENTITIES FOR NESTED QUOTES - use &quot; for quotes inside node labels:
      WRONG: F["Result: [{1, :a, \"cat\"}, {2, :b, \"dog\"}]"]
      RIGHT: F["Result: [{1, :a, &quot;cat&quot;}, {2, :b, &quot;dog&quot;}]"]
      When you MUST show quotes inside a quoted label, replace inner " with &quot;
      This is the ONLY way to have quotes inside ["..."] labels in Mermaid.

  18. ESCAPE SEQUENCES - replace \n, \t, \r with words:
      WRONG: D["split(\"\n\")"]  or  D[split("\n")]
      RIGHT: D["split by newline"]  or  D["split newline"]
      Mermaid interprets \n as a line break. Use descriptive words instead.

  19. STRING LITERALS IN FUNCTION CALLS - simplify instead of escaping:
      WRONG: G["print_table([\"a\", \"b\", \"c\"])"]
      RIGHT: G["print_table(headers)"]  or  G["print_table(columns)"]
      When a label has a function call with string array arguments, replace the
      array with a descriptive word like "headers", "items", "columns", etc.

  20. UNRECOVERABLE TRUNCATED EDGES - remove completely:
      WRONG: K -->|"[{  (incomplete edge with no target)
      RIGHT: (remove the entire line)
      If an edge has no target node or is clearly truncated mid-syntax, delete it.

  APPROACH: Go through EACH node label [like this] and EACH edge label |like this| and fix any that contain ( ) { } . ! : | @ \ or quotes. Edge labels with special chars MUST be quoted. Verify all brackets match, arrows are valid, no escape sequences. For nested quotes, prefer simplification; if quotes are essential, use &quot; HTML entity. Remove unrecoverable truncated lines.

  Return ONLY valid JSON:

  {
    "mermaid": "fixed mermaid code here"
  }

  Keep the diagram's structure. Only fix syntax, don't redesign.
  """

  # Default functions - return module attributes directly (used by DiagramForge.AI fallback)

  @doc """
  Returns the default system prompt for concept extraction.
  Used as fallback when no DB customization exists.
  """
  def default_concept_system_prompt, do: @concept_system_prompt

  @doc """
  Returns the default system prompt for diagram generation.
  Used as fallback when no DB customization exists.
  """
  def default_diagram_system_prompt, do: @diagram_system_prompt

  @doc """
  Returns the default template for fixing Mermaid syntax errors.
  Uses {{MERMAID_CODE}}, {{SUMMARY}}, and {{ERROR_CONTEXT}} placeholders.
  Used as fallback when no DB customization exists.
  """
  def default_fix_mermaid_syntax_prompt, do: @fix_mermaid_syntax_prompt

  # Public API - checks DB first, falls back to defaults

  @doc """
  Returns the system prompt for concept extraction.
  Checks database for customized version first, falls back to default.
  """
  def concept_system_prompt do
    DiagramForge.AI.get_prompt("concept_system")
  end

  @doc """
  Returns the system prompt for diagram generation.
  Checks database for customized version first, falls back to default.
  """
  def diagram_system_prompt do
    DiagramForge.AI.get_prompt("diagram_system")
  end

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

    Return JSON with both diagram and concept information:

    {
      "title": "Readable title for the diagram",
      "domain": "elixir | phoenix | http | kafka | llm | agents | other",
      "tags": ["list", "of", "short", "tags"],
      "mermaid": "mermaid code here",
      "summary": "1–2 sentence explanation of what the diagram shows",
      "notes_md": "markdown bullets explaining key points",
      "concept": {
        "name": "short name for the main concept (e.g., 'GenServer', 'ElevenLabs', 'OAuth')",
        "short_description": "1–2 sentence description suitable for learners",
        "category": "elixir | phoenix | http | kafka | llm | agents | other"
      }
    }

    The concept should identify the main topic/entity being explained, not just repeat the diagram title.
    Only output JSON.
    """
  end

  @doc """
  Returns the user prompt for fixing Mermaid syntax errors.

  Takes the broken Mermaid code, the diagram's summary/context, and optionally
  the actual parse error from the client. Checks database for customized template
  first, falls back to default.

  Template uses {{MERMAID_CODE}}, {{SUMMARY}}, and {{ERROR_CONTEXT}} placeholders.
  """
  def fix_mermaid_syntax_prompt(broken_mermaid, summary, mermaid_error \\ nil) do
    error_context = format_error_context(mermaid_error)

    DiagramForge.AI.get_prompt("fix_mermaid_syntax")
    |> String.replace("{{MERMAID_CODE}}", broken_mermaid)
    |> String.replace("{{SUMMARY}}", summary || "")
    |> String.replace("{{ERROR_CONTEXT}}", error_context)
  end

  # Format the Mermaid error for inclusion in the AI prompt
  defp format_error_context(nil), do: ""

  defp format_error_context(error) when is_map(error) do
    parts = [
      "\n\nPARSE ERROR FROM MERMAID #{error[:mermaid_version] || @mermaid_version}:",
      error[:message] && "Error: #{error[:message]}",
      error[:line] && "Line: #{error[:line]}",
      error[:expected] && "Expected: #{error[:expected]}"
    ]

    parts
    |> Enum.filter(& &1)
    |> Enum.join("\n")
    |> then(&(&1 <> "\n\nFocus on fixing this specific error first."))
  end

  defp format_error_context(_), do: ""
end
