defmodule DiagramForgeWeb.Admin.PromptEditLiveTest do
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
      {:error, {:redirect, %{to: "/", flash: flash}}} =
        live(conn, ~p"/admin/prompts/concept_system/edit")

      assert flash["error"] =~ "logged in"
    end

    test "redirects to home when not superadmin", %{conn: conn} do
      user = fixture(:user, email: "regular@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: user.id})

      {:error, {:redirect, %{to: "/", flash: flash}}} =
        live(conn, ~p"/admin/prompts/concept_system/edit")

      assert flash["error"] =~ "superadmin"
    end

    test "allows access for superadmin", %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})

      {:ok, _view, html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      assert html =~ "Edit Prompt"
    end
  end

  describe "edit page display" do
    setup %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})
      %{conn: conn}
    end

    test "displays prompt key and description", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      assert html =~ "concept_system"
      assert html =~ "concept extraction"
    end

    test "shows Default badge for uncustomized prompt", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      assert html =~ "Default"
    end

    test "shows Customized badge for DB-stored prompt", %{conn: conn} do
      fixture(:prompt, key: "concept_system", content: "Custom content")

      {:ok, _view, html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      assert html =~ "Customized"
    end

    test "displays current content in textarea", %{conn: conn} do
      {:ok, _view, html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      # Default prompt content should be in the textarea
      assert html =~ "technical teaching assistant"
    end

    test "displays customized content in textarea", %{conn: conn} do
      fixture(:prompt, key: "concept_system", content: "My custom prompt content")

      {:ok, _view, html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      assert html =~ "My custom prompt content"
    end

    test "has Back button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      assert has_element?(view, "a[href='/admin/prompts']")
    end

    test "has Cancel button", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      assert has_element?(view, "a[href='/admin/prompts']", "Cancel")
    end
  end

  describe "form validation" do
    setup %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})
      %{conn: conn}
    end

    test "shows error when content is empty", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      html =
        view
        |> form("#prompt-form", prompt: %{content: ""})
        |> render_change()

      assert html =~ "can&#39;t be blank" or html =~ "can't be blank"
    end
  end

  describe "saving prompts" do
    setup %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})
      %{conn: conn}
    end

    test "creates new prompt record when saving default", %{conn: conn} do
      # Ensure no DB record exists
      AI.invalidate_cache("concept_system")

      {:ok, view, _html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      new_content = "My brand new custom prompt"

      view
      |> form("#prompt-form", prompt: %{content: new_content})
      |> render_submit()

      # Should redirect to list
      assert_redirect(view, "/admin/prompts")

      # Verify DB record was created
      AI.invalidate_cache("concept_system")
      assert AI.get_prompt("concept_system") == new_content
    end

    test "updates existing prompt record", %{conn: conn} do
      fixture(:prompt, key: "concept_system", content: "Original custom content")
      AI.invalidate_cache("concept_system")

      {:ok, view, _html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      updated_content = "Updated custom content"

      view
      |> form("#prompt-form", prompt: %{content: updated_content})
      |> render_submit()

      # Should redirect to list
      assert_redirect(view, "/admin/prompts")

      # Verify DB record was updated
      AI.invalidate_cache("concept_system")
      assert AI.get_prompt("concept_system") == updated_content
    end

    test "shows flash message on successful save", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      view
      |> form("#prompt-form", prompt: %{content: "New content"})
      |> render_submit()

      flash = assert_redirect(view, "/admin/prompts")
      assert flash["info"] =~ "saved"
    end
  end

  describe "navigation from edit page" do
    setup %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})
      %{conn: conn}
    end

    test "Back button navigates to prompts list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      view
      |> element("a.btn-ghost[href='/admin/prompts']", "Back")
      |> render_click()

      assert_redirect(view, "/admin/prompts")
    end

    test "Cancel button navigates to prompts list", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/prompts/concept_system/edit")

      view
      |> element("a", "Cancel")
      |> render_click()

      assert_redirect(view, "/admin/prompts")
    end
  end
end
