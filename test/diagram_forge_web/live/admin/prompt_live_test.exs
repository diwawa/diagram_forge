defmodule DiagramForgeWeb.Admin.PromptLiveTest do
  use DiagramForgeWeb.ConnCase

  import Phoenix.LiveViewTest

  alias DiagramForge.AI

  setup do
    # Set up superadmin email for testing
    Application.put_env(:diagram_forge, :superadmin_email, "admin@example.com")

    on_exit(fn ->
      Application.delete_env(:diagram_forge, :superadmin_email)
    end)

    :ok
  end

  describe "access control" do
    test "redirects to home when not authenticated", %{conn: conn} do
      {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/admin/prompts")

      assert flash["error"] =~ "logged in"
    end

    test "redirects to home when not superadmin", %{conn: conn} do
      user = fixture(:user, email: "regular@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: user.id})

      {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/admin/prompts")

      assert flash["error"] =~ "superadmin"
    end

    test "allows access for superadmin", %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})

      {:ok, _view, html} = live(conn, ~p"/admin/prompts")

      assert html =~ "AI Prompts"
    end
  end

  describe "prompt list" do
    setup %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})
      %{conn: conn}
    end

    test "displays all known prompts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/prompts")

      assert html =~ "concept_system"
      assert html =~ "diagram_system"
    end

    test "shows Default badge for uncustomized prompts", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/prompts")

      # Both prompts should show Default badge
      assert html =~ "Default"
    end

    test "shows Customized badge for DB-stored prompts", %{conn: conn} do
      # Create a customized prompt
      fixture(:prompt, key: "concept_system", content: "Custom content")

      {:ok, _view, html} = live(conn, ~p"/admin/prompts")

      assert html =~ "Customized"
    end

    test "displays prompt content preview", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/prompts")

      # Should show content from default prompts
      assert html =~ "technical teaching assistant"
    end

    test "displays Edit button for each prompt", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/prompts")

      assert has_element?(view, "a[href='/admin/prompts/concept_system/edit']")
      assert has_element?(view, "a[href='/admin/prompts/diagram_system/edit']")
    end

    test "Reset button is disabled for default prompts", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/prompts")

      # All prompts are default, so Reset buttons should be disabled
      assert has_element?(view, "button[disabled][phx-value-key='concept_system']")
    end

    test "Reset button is enabled for customized prompts", %{conn: conn} do
      fixture(:prompt, key: "concept_system", content: "Custom content")

      {:ok, view, _html} = live(conn, ~p"/admin/prompts")

      # The Reset button for concept_system should NOT be disabled
      refute has_element?(view, "button[disabled][phx-value-key='concept_system']")
      assert has_element?(view, "button[phx-value-key='concept_system']")
    end
  end

  describe "reset to default" do
    setup %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})
      %{conn: conn}
    end

    test "resets prompt to default value", %{conn: conn} do
      # Create a customized prompt
      fixture(:prompt, key: "concept_system", content: "Custom content")
      AI.invalidate_cache("concept_system")

      {:ok, view, _html} = live(conn, ~p"/admin/prompts")

      # Verify customized content is shown
      assert render(view) =~ "Customized"

      # Click reset button
      view
      |> element("button[phx-value-key='concept_system']")
      |> render_click()

      # Should show success message and default badge
      html = render(view)
      assert html =~ "reset to default"
      assert html =~ "Default"

      # Verify cache was invalidated and default is used
      AI.invalidate_cache("concept_system")
      assert AI.get_prompt("concept_system") =~ "technical teaching assistant"
    end
  end

  describe "navigation" do
    setup %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})
      %{conn: conn}
    end

    test "sidebar contains Prompts link", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/prompts")

      assert has_element?(view, "a[href='/admin/prompts']")
    end

    test "topbar contains Prompts link", %{conn: conn} do
      conn = get(conn, ~p"/admin/prompts")
      html = html_response(conn, 200)

      assert html =~ "Prompts"
    end
  end
end
