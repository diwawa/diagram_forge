# Broken Mermaid Diagrams - Analysis Request

Total: 146 diagrams, 16 broken (11%)

---

## 1. Interactive Elixir Session
**ID:** `fecf898c-54fe-4b37-98ad-3f0117c5f0ae`
**Error:** Invalid `-->>` arrow syntax

```mermaid
flowchart TD;
    A["Terminal"] -->|"input: $ iex"| B["IEx"];
    B --> C["Enter Elixir code"];
    C -->|"output: result"| D["Output"];
    B -->|"h()/h(Enum)"| E["IEx.Helpers"];
    E -->>|"Provides info"| F["Function Help"];
    F -->|"exits: Ctrl+C"| G["Exit IEx"];
```

---

## 2. Elixir Error Handling Flow
**ID:** `4c763f11-bb40-42a7-975e-f24d32572460`
**Error:** Escaped parentheses and nested quotes

```mermaid
flowchart TD;
    A["File.open"] -->|"{:ok, file}"| B["process(file)"];
    A -->|"{:error, message}"| C["IO.puts"];
    A2["File.open('config_file')"] -->|"{:ok, file}"| B;
    A2 -->|"{:error, message}"| D["raise 'Failed to open config file: ' + message"];
    A3["File.open!\("config_file"\)"] -->|"file"| B;
    E["Raise Example"] -->|"error: msg"| F["RuntimeError"];
    G["User File"] -->|"{:error, msg}"| C;
    G -->|"{:ok, file}"| B;
```

---

## 3. Elixir Data Types and Access Methods
**ID:** `b81a1ed6-b6d8-4d48-9977-5c5740054162`
**Error:** Nested quotes with colon - `colors[":red"]`

```mermaid
flowchart TD
    A["Map"] -->|"colors[":red"]"| B["16711680"]
    A -->|"colors.green"| C["65280"]
    D["Binary"] -->|"<< 1, 2 >>"| E["<<1, 2>"]
    E -->|"byte_size"| F["2"]
    D -->|"<<3 :: size(2), 5 :: size(4), 1 :: size(2) >>"| G["<<213>"]
    G -->|"byte_size"| H["1"]
```

---

## 4. List Module Functions in Elixir
**ID:** `8fe16104-7a0e-41b9-a197-46b21bc1c69e`
**Error:** Mismatched brackets - `[1, 2, 3, 4, 5, 6"]]`

```mermaid
flowchart TD
    A[List Concatenation] -->|"[1,2,3] ++ [4,5,6]"| B["Result: [1, 2, 3, 4, 5, 6"]]
    A -->|"List.flatten([[[1], 2], [[[3]]]])"| C["Result: [1, 2, 3"]]
    A -->|"List.foldl([1,2,3], "", fn value, acc -> #{value}(#{acc}) end)"| D[Result: "3(2(1()))"]
    A -->|"List.foldr([1,2,3], "", fn value, acc -> #{value}(#{acc}) end)"| E[Result: "1(2(3()))"]
    A -->|"List.zip([[1,2,3], [:a,:b,:c], ["cat", dog]])"| F[Result: [{1, :a, "cat"}, {2, :b, "dog"}]]
```

---

## 5. Elixir Sigils and Character Lists
**ID:** `0300fb24-cfea-42ec-b46b-2f052f99ea73`
**Error:** Incomplete/truncated diagram

```mermaid
flowchart TD;
    A[
```

---

## 6. Elixir Mix Project Structure and Commands
**ID:** `5a03c017-1ad1-4fa8-813d-fac7d3d6d991`
**Error:** Unquoted node with quotes inside - `A[mix new "issues"]`

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

---

## 7. Enum Operations in Elixir
**ID:** `e2f5824b-b4b5-4856-8a41-44cdf69906ea`
**Error:** Nested quotes in edge label

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

---

## 8. Data Formatting Process in Elixir
**ID:** `05f73396-20ba-44ca-b5d9-5a7105a8e6fe`
**Error:** Nested quotes in node label

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

---

## 9. Elixir Sigils Implementation
**ID:** `83f71de0-378b-4e31-a59f-6a07559f0cfc`
**Error:** Unquoted parentheses in node - `D[split("\n")]`

```mermaid
flowchart TD;
    A[LineSigil] -->|"~l"| B["sigil_l(lines, _opts)"];
    B -->|"String.rstrip"| C[rstrip];
    B -->|"String.split"| D[split("\n")];
    E[Example] -->|"import LineSigil"| A;
    E -->|"~l"| F["lines()"];
    F -->|"IO.inspect"| G[Print list];
```

---

## 10. FibAgent Process Management
**ID:** `4c975554-47fc-41b7-bd84-63555b36ad12`
**Error:** Mismatched brackets - `I["result"}`

```mermaid
flowchart TD
    A["FibAgent"] -->|"{:ok, pid}"| B["Agent.start_link"]
    B --> C["cache"]
    C -->|"fib(pid, n)"| D["Agent.get_and_update"]
    D --> E["do_fib(cache, n)"]
    E -->|"{cached, cache}"| F["cached"]
    E -->|"{val, cache}"| G["do_fib(cache, n-1)"]
    G --> H["result = val + cache[n-2]"]
    H -->|"{result, Dict.put(cache, n, result)}"| I["result"}
```

---

## 11. GenServer Call Flow with Debug Options
**ID:** `cc4ec3f9-def5-4f7e-bc5b-02d3b5cc6068`
**Error:** Mismatched brackets - `B["GenServer.call(pid, :next_number")]`

```mermaid
flowchart TD
    A["Start GenServer"] -->|"{:ok, pid}"| B["GenServer.call(pid, :next_number")]
    B -->|"100"| C["Response: 100"]
    B -->|"{:ok, pid}"| D["Debug: :trace"]
    D -->|"*DBG* got call"| E["New state: 101"]
    E -->|"102"| F["Response: 101"]
    G["Sys Functions"] -->|"trace"| D
    G -->|"statistics"| H["Get Statistics"]
    H -->|"{:ok, stats}"| I["Show Current State"]
```

---

## 12. Erlang Group Leader Registration
**ID:** `4f56b8c1-269b-4101-8d2e-266882ce8a92`
**Error:** Nested quotes - `E["IO.puts(two, "Hello")"]`

```mermaid
flowchart TD
    A["Node.connect"] -->|"true"| B["Register PID"]
    B -->|":yes"| C["Global Name :two"]
    C --> D["two = :global.whereis_name :two"]
    D --> E["IO.puts(two, "Hello")"]
    D --> F["IO.puts(two, "World!")"]
    E --> G["Hello"]
    F --> H["World"]
```

---

## 13. Elixir Macros and Scope
**ID:** `a8736352-e8b9-4566-870c-332e8ead7c6c`
**Error:** Unclosed quote in node label

```mermaid
flowchart TD
    A["Scope"] --> B["update_local(val)"]
    B --> C["quote do"]
    C --> D["local = unquote(val)"]
    D --> E["IO.puts 'End of macro body, local = ']
    B --> F["IO.puts 'In macro definition, local = ']
    A --> G["Test"]
    G --> H["local = 123"]
    G --> I["Scope.update_local('cat')"]
    G --> J["IO.puts 'On return, local = ']
```

---

## 14. Error Handling in Elixir
**ID:** `62d8fff7-f14e-4181-8fa1-f2ef7ec5ff87`
**Error:** Truncated/incomplete diagram

```mermaid
flowchart TD;
    A["start(n)"] -->|"try"| B["raise_error(n)"];
    B -->|"0"| C["No error"];
    B -->|"1"| D["1 / 0"];
    B -->|"2"| E["raise_error(99)"];
    B -->|"3"| F["File.mkdir!('/not_allowed')"];
    A -->|"catch"| G["FunctionClauseError"];
    A -->|"catch"| H["RuntimeError"];
    A -->|"catch"| I["ArithmeticError"];
    A -->|"catch"| J["other_errors"];
    G -->|"NO MATCH"| K["no function match or runtime error"];
    I -->|"{error}"| L["Uh-oh! Arithmetic error"];
    J -->|"ANY"| M["Disaster! other_errors"];
    A -->|
```

---

## 15. Elixir Type Specifications
**ID:** `2cdd0b2f-647f-47d1-be59-dccc9edf6997`
**Error:** Unquoted `@` symbol in node - `A[@spec]`

```mermaid
flowchart TD;
    A[@spec] --> B[type_name]
    B --> C[type_specification]
    A --> D[function_name]
    D --> E[param1_type]
    D --> F[param2_type]
    A --> G[return_type]
    C --> H[any]
    C --> I[number]
    C --> J["tuple | list"]
```

---

## 16. Color Sigil Functionality
**ID:** `1ea72d71-5781-467e-85bf-7752f18a2da4`
**Error:** Nested quotes with colon - `G["@color_map[":hsb"]"]`

```mermaid
flowchart TD;
    A["ColorSigil"] --> B["sigil_c(color_name, [])"];
    A --> C["sigil_c(color_name, 'r')"];
    A --> D["sigil_c(color_name, 'h')"];
    B -->|"{:ok, rgb}"| E["_c(color_name, :rgb)"];
    C -->|"{:ok, rgb}"| E;
    D -->|"{:ok, hsb}"| F["_c(color_name, :hsb)"];
    F --> G["@color_map[":hsb"]"];
    E --> H["@color_map[":rgb"]"];
```

---

## Summary of Error Patterns

1. **Invalid `-->>` arrow** (1 case) - #1
2. **Escaped parentheses `\(` `\)`** (1 case) - #2
3. **Nested quotes in edge/node labels** (5 cases) - #3, #7, #8, #12, #16
4. **Mismatched brackets `"]]` or `"}`** (3 cases) - #4, #10, #11
5. **Truncated/incomplete diagrams** (2 cases) - #5, #14
6. **Unquoted special chars in nodes** (2 cases) - #6, #15
7. **Unquoted parentheses in nodes** (1 case) - #9
8. **Unclosed quotes** (1 case) - #13
