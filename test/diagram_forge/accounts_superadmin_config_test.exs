defmodule DiagramForge.AccountsSuperadminConfigTest do
  @moduledoc """
  Tests for superadmin configuration edge cases.

  This test file is intentionally non-async because it modifies global
  Application config (superadmin_email), which would cause race conditions
  with other async tests that rely on this config.
  """
  use DiagramForge.DataCase, async: false

  alias DiagramForge.Accounts
  alias DiagramForge.Accounts.User

  describe "user_is_superadmin?/1 config edge cases" do
    test "returns false when superadmin_email is not configured" do
      # Save current value
      original = Application.get_env(:diagram_forge, :superadmin_email)

      try do
        # Temporarily remove the config
        Application.delete_env(:diagram_forge, :superadmin_email)

        user = %User{email: "any@example.com"}
        assert Accounts.user_is_superadmin?(user) == false
      after
        # Always restore to prevent affecting other tests
        if original do
          Application.put_env(:diagram_forge, :superadmin_email, original)
        end
      end
    end
  end
end
