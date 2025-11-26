# Mermaid Diagram Syntax Fixing

This document explains how DiagramForge uses AI to fix broken Mermaid diagrams.

## Overview

When a Mermaid diagram fails to render, users can click "Fix Syntax" to have AI automatically repair common syntax errors. The system achieves near-100% fix rates, with most diagrams fixed on the first attempt.

## How It Works

### 1. Error Detection

The frontend Mermaid hook (`assets/js/app.js`) catches render errors and sends error details to the LiveView:

```javascript
// Caught in the Mermaid hook
{
  message: "Parse error on line 3...",
  line: 3,
  expected: "SEMI, NEWLINE",
  mermaidVersion: "11.12.1"
}
```

### 2. Fix Request

When the user clicks "Fix Syntax", the LiveView sends the broken diagram to the AI with:
- The broken Mermaid source code
- The diagram's summary/context
- The specific parse error from Mermaid (if available)

### 3. AI Processing

The AI uses a comprehensive prompt (`lib/diagram_forge/ai/prompts.ex`) containing 26 rules for fixing common Mermaid 11.x syntax issues.

### 4. Result Handling

- If the fix renders successfully, the diagram is updated
- If it still fails, the user can retry (usually works within 1-3 attempts)
- The error is displayed so users can manually edit if needed

## Common Syntax Issues

The AI is trained to fix these categories of errors:

### Quoting Issues
| Problem | Example | Fix |
|---------|---------|-----|
| Missing quotes on special chars | `A[File.open!]` | `A["File.open!"]` |
| Nested quotes | `A["File.open!(\"file\")"]` | `A["File.open!(file)"]` |
| Empty string literals | `C["name: \"\""]` | `C["name: empty string"]` |
| Unquoted edge labels | `-->\|{:ok}\|` | `-->\|"{:ok}"\|` |

### Bracket Issues
| Problem | Example | Fix |
|---------|---------|-----|
| Missing brackets | `A"text"` | `A["text"]` |
| Mismatched brackets | `A["text}` | `A["text"]` |
| Double brackets | `B["[1,2,3"]]` | `B["[1,2,3]"]` |

### Special Characters
| Problem | Example | Fix |
|---------|---------|-----|
| Unquoted @ symbol | `A[@spec]` | `A["@spec"]` |
| Unquoted curly braces | `F[try { code }]` | `F["try { code }"]` |
| Escape sequences | `D["split(\"\n\")"]` | `D["split by newline"]` |

### Code Literal Simplification
| Problem | Example | Fix |
|---------|---------|-----|
| Array literals | `\|"[\"a\", \"b\"]"\|` | `\|"list of items"\|` or `\|"[&quot;a&quot;, &quot;b&quot;]"\|` |
| Function with strings | `G["@map[\":key\"]"]` | `G["@map[:key]"]` |
| Enum.join with separator | `\|"Enum.join(x, \", \")"\|` | `\|"Enum.join with separator"\|` |

## Prompt Architecture

The system uses two prompts:

### Generation Prompt (`@diagram_system_prompt`)
Brief rules to prevent syntax errors during initial diagram generation. Focuses on:
- Proper quoting for special characters
- Avoiding code literals in labels
- Using descriptive text instead of nested quotes

### Fix Prompt (`@fix_mermaid_syntax_prompt`)
Detailed diagnostic checklist with 26 rules. Each rule includes:
- WRONG and RIGHT examples
- Explanation of why it breaks
- How to fix it

The fix prompt is more verbose because it needs to diagnose unknown issues, while the generation prompt is concise to fit within context limits.

## Configuration

Prompts can be customized via the admin panel at `/admin/prompts`. The database-stored prompts take precedence over the defaults in code.

## Validation Scripts

For bulk validation of diagrams:

```bash
# Export diagrams from database
mix run scripts/export_diagrams.exs

# Validate using mermaid-cli
cd assets && node ../scripts/validate_mermaid.mjs
```

Results are written to `/tmp/diagram_validation_results.json`.

## Related Files

- `lib/diagram_forge/ai/prompts.ex` - Prompt definitions
- `lib/diagram_forge_web/live/diagram_studio_live.ex` - Fix syntax handling
- `assets/js/app.js` - Mermaid hook with error detection
- `scripts/validate_mermaid.mjs` - Bulk validation script
