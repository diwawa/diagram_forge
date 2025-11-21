[
  # Ignore ExUnit.Callbacks and ExUnit.CaseTemplate warnings in test support files
  # These are compile-time modules that Dialyzer doesn't see properly
  ~r/test\/support\/.*_case.ex.*ExUnit.Callbacks/,
  ~r/test\/support\/.*_case.ex.*ExUnit.CaseTemplate/
]
