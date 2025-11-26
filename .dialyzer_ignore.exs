[
  # Ignore ExUnit.Callbacks and ExUnit.CaseTemplate warnings in test support files
  # These are compile-time modules that Dialyzer doesn't see properly
  ~r/test\/support\/.*_case.ex.*ExUnit.Callbacks/,
  ~r/test\/support\/.*_case.ex.*ExUnit.CaseTemplate/,

  # Ignore Mix module warnings in mix tasks - Mix is not in the PLT
  ~r/lib\/mix\/tasks\/.*\.ex.*Mix\.Task/,
  ~r/lib\/mix\/tasks\/.*\.ex.*Mix\.shell/,
  ~r/lib\/mix\/tasks\/.*\.ex.*Mix\.raise/
]
