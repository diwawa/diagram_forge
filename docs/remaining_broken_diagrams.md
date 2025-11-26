# Remaining Broken Mermaid Diagrams - Round 2 Analysis

After AI fix attempts, 5 diagrams remain broken. These have complex nested quoting patterns.

**Success rate so far: 11/16 (69%)**

---

## 1. List Module Functions in Elixir
**ID:** `8fe16104-7a0e-41b9-a197-46b21bc1c69e`
**Problem:** Complex nested quotes in edge labels with string literals and interpolation

### Original (Broken):
```mermaid
flowchart TD
    A[List Concatenation] -->|"[1,2,3] ++ [4,5,6]"| B["Result: [1, 2, 3, 4, 5, 6"]]
    A -->|"List.flatten([[[1], 2], [[[3]]]])"| C["Result: [1, 2, 3"]]
    A -->|"List.foldl([1,2,3], "", fn value, acc -> #{value}(#{acc}) end)"| D[Result: "3(2(1()))"]
    A -->|"List.foldr([1,2,3], "", fn value, acc -> #{value}(#{acc}) end)"| E[Result: "1(2(3()))"]
    A -->|"List.zip([[1,2,3], [:a,:b,:c], ["cat", dog]])"| F[Result: [{1, :a, "cat"}, {2, :b, "dog"}]]
```

### AI Attempted Fix (Still Broken):
```mermaid
flowchart TD
    A[List Concatenation] -->|"[1,2,3] ++ [4,5,6]"| B["Result: [1, 2, 3, 4, 5, 6]" sheet
    A -->|"List.flatten([[[1], 2], [[[3]]]])"| C["Result: [1, 2, 3]" sheet
    A -->|"List.foldl([1,2,3], "", fn value, acc -> #{value}(#{acc}) end)"| D["Result: 3(2(1()))" sheet
    A -->|"List.foldr([1,2,3], "", fn value, acc -> #{value}(#{acc}) end)"| E["Result: 1(2(3()))" sheet
    A -->|"List.zip([[1,2,3], [:a,:b,:c], ["cat", dog]])"| F["Result: [{1, :a, \"cat\"}, {2, :b, dog}]" sheet
```

**Issues:**
- AI hallucinated "sheet" at end of lines
- Still has `\"cat\"` escaped quotes
- Edge labels contain empty strings `""` which conflict with label quoting

---

## 2. Elixir Mix Project Structure and Commands
**ID:** `5a03c017-1ad1-4fa8-813d-fac7d3d6d991`
**Problem:** Unquoted node with quotes inside

### Original (Broken):
```mermaid
flowchart TD
    A[mix new "issues"] --> B["Creating files"]
    A --> C["Run mix commands"]
    C -->|"#{:ok, pid}"| D[mix test]
    C -->|"#{:ok, pid}"| E["iex -S mix"]
    B --> F["issues/"]
    F --> G["lib/"]
    F --> H["test/"]
    F --> I["config/"]
    F --> J["mix.exs"]
```

### AI Attempted Fix (Still Broken - Unchanged):
```mermaid
flowchart TD
    A[mix new "issues"] --> B["Creating files"]
    A --> C["Run mix commands"]
    C -->|"{:ok, pid}"| D[mix test]
    C -->|"{:ok, pid}"| E["iex -S mix"]
    B --> F["issues/"]
    F --> G["lib/"]
    F --> H["test/"]
    F --> I["config/"]
    F --> J["mix.exs"]
```

**Issues:**
- `A[mix new "issues"]` has quotes inside unquoted node - must be `A["mix new issues"]`
- AI did not fix this

---

## 3. Enum Operations in Elixir
**ID:** `e2f5824b-b4b5-4856-8a41-44cdf69906ea`
**Problem:** Nested quotes in edge label with comma separator

### Original (Broken):
```mermaid
flowchart TD;
    A["split_while(list, &(&1 < 4))"] -->|"{[1, 2, 3], [4, 5]}"| B["Join(collection)"];
    B -->|"12345"| C["Join(collection, ", ")"];
    D["Predicate Operations"] --> E["Enum.all?(list, &(&1 < 4))"];
    E -->|"false"| F["Enum.any?(list, &(&1 < 4))"];
    F -->|"true"| G["Enum.member?(list, 4)"];
    G -->|"true"| H["Enum.empty?(list)"];
    H -->|"false"| I["Merge Collections"];
    I --> J["Enum.zip(list, [:a, :b, :c])"];
    J -->|"[{1, :a}, {2, :b}, {3, :c}]"| K["Enum.with_index(list)"];
    K -->|"[{
```

### AI Attempted Fix (Still Broken):
```mermaid
flowchart TD;
    A["split_while(list, &(&1 < 4))"] -->|"{[1, 2, 3], [4, 5]}"| B["Join(collection)"];
    B -->|"12345"| C["Join(collection, ", ")"];
    D["Predicate Operations"] --> E["Enum.all?(list, &(&1 < 4))"];
    E -->|"false"| F["Enum.any?(list, &(&1 < 4))"];
    F -->|"true"| G["Enum.member?(list, 4)"];
    G -->|"true"| H["Enum.empty?(list)"];
    H -->|"false"| I["Merge Collections"];
    I --> J["Enum.zip(list, [:a, :b, :c])"];
    J -->|"[{1, :a}, {2, :b}, {3, :c}]"| K["Enum.with_index(list)"];
```

**Issues:**
- `C["Join(collection, ", ")"]` has nested quotes - the `", "` argument
- Should simplify to `C["Join with separator"]` or similar

---

## 4. Data Formatting Process in Elixir
**ID:** `05f73396-20ba-44ca-b5d9-5a7105a8e6fe`
**Problem:** Nested quotes in node label containing array of strings

### Original (Broken):
```mermaid
flowchart TD
    A["process({user, project, count})"] --> B["Issues.GithubIssues.fetch"]
    B --> C["decode_response"]
    C --> D["convert_to_list_of_hashdicts"]
    D --> E["sort_into_ascending_order"]
    E --> F["Enum.take(count)"]
    F --> G["print_table_for_columns(["number", "created_at", "title"])" ]
    G --> H["table_formatter.ex"]
    H --> I["print_table_for_columns(rows, headers)"]
    I --> J["split_into_columns(rows, headers)"]
    I --> K["widths_of(data_by_columns)"]
    I --> L["format_for(column_widths)"]
```

### AI Attempted Fix (Still Broken):
```mermaid
flowchart TD
    A["process(user, project, count)"] --> B["Issues.GithubIssues.fetch"]
    B --> C["decode_response"]
    C --> D["convert_to_list_of_hashdicts"]
    D --> E["sort_into_ascending_order"]
    E --> F["Enum.take(count)"]
    F --> G["print_table_for_columns([\"number\", \"created_at\", \"title\"])" ]
    G --> H["table_formatter.ex"]
    H --> I["print_table_for_columns(rows, headers)"]
    I --> J["split_into_columns(rows, headers)"]
    I --> K["widths_of(data_by_columns)"]
    I --> L["format_for(column_widths)"]
```

**Issues:**
- AI used `\"` escaped quotes which Mermaid doesn't support
- Should simplify to `G["print_table_for_columns(headers)"]` or similar

---

## 5. Elixir Sigils Implementation
**ID:** `83f71de0-378b-4e31-a59f-6a07559f0cfc`
**Problem:** Newline character `\n` in node label

### Original (Broken):
```mermaid
flowchart TD;
    A[LineSigil] -->|"~l"| B["sigil_l(lines, _opts)"];
    B -->|"String.rstrip"| C[rstrip];
    B -->|"String.split"| D[split("\n")];
    E[Example] -->|"import LineSigil"| A;
    E -->|"~l"| F["lines()"];
    F -->|"IO.inspect"| G[Print list];
```

### AI Attempted Fix (Still Broken):
```mermaid
flowchart TD;
    A[LineSigil] -->|"~l"| B["sigil_l(lines, _opts)"];
    B -->|"String.rstrip"| C[rstrip];
    B -->|"String.split"| D[split("\n")];
    E[Example] -->|"import LineSigil"| A;
    E -->|"~l"| F[lines];
    F -->|"IO.inspect"| G[Print list];
```

**Issues:**
- `D[split("\n")]` - the `\n` is being interpreted as a literal newline
- Should be `D["split by newline"]` or `D["split(newline)"]`

---

## Common Patterns in These Failures

1. **String literals inside labels**: When Elixir code contains `""` empty strings or `"text"` string literals, these create impossible quoting situations

2. **Escaped quotes don't work**: Mermaid does NOT support `\"` - the AI keeps trying this

3. **AI reluctance to simplify**: The AI tries to preserve exact code syntax instead of describing it

4. **Hallucination**: In one case, the AI added random text ("sheet")

## Suggested Fix Strategy

For these cases, the content should be **heavily simplified** to avoid nested quotes entirely:
- `["number", "created_at"]` → `headers array` or `column names`
- `split("\n")` → `split by newline`
- `Join(collection, ", ")` → `Join with comma separator`
- `mix new "issues"` → `mix new project`
