defmodule DiagramForgeWeb.Admin.DiagramResourceLiveTest do
  use DiagramForgeWeb.ConnCase

  import Phoenix.LiveViewTest

  alias DiagramForge.Diagrams.Diagram
  alias DiagramForge.Repo

  describe "bulk visibility item actions" do
    setup %{conn: conn} do
      superadmin = fixture(:user, email: "admin@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: superadmin.id})

      # Create test diagrams with different visibilities
      diagram1 =
        fixture(:diagram, visibility: :private, user_id: superadmin.id, title: "Test Diagram 1")

      diagram2 =
        fixture(:diagram, visibility: :private, user_id: superadmin.id, title: "Test Diagram 2")

      diagram3 =
        fixture(:diagram, visibility: :unlisted, user_id: superadmin.id, title: "Test Diagram 3")

      %{conn: conn, superadmin: superadmin, diagrams: [diagram1, diagram2, diagram3]}
    end

    test "displays bulk action buttons when items are selected", %{
      conn: conn,
      diagrams: [diagram1 | _]
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # Select a diagram by clicking its checkbox
      view
      |> element("#select-input-#{diagram1.id}")
      |> render_click()

      # Now the bulk action buttons should be visible and enabled
      html = render(view)

      assert html =~ "Make Public"
      assert html =~ "Make Unlisted"
      assert html =~ "Make Private"
    end

    test "Make Public action updates diagram visibility", %{conn: conn, diagrams: [diagram1 | _]} do
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # Select the diagram
      view
      |> element("#select-input-#{diagram1.id}")
      |> render_click()

      # Click "Make Public" action
      view
      |> element("button", "Make Public")
      |> render_click()

      # Confirm the action by submitting the modal form
      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      # Verify the diagram was updated in the database
      updated_diagram = Repo.get!(Diagram, diagram1.id)
      assert updated_diagram.visibility == :public
    end

    test "Make Unlisted action updates diagram visibility", %{
      conn: conn,
      diagrams: [diagram1 | _]
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # Select the diagram
      view
      |> element("#select-input-#{diagram1.id}")
      |> render_click()

      # Click "Make Unlisted" action
      view
      |> element("button", "Make Unlisted")
      |> render_click()

      # Confirm the action by submitting the modal form
      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      # Verify the diagram was updated
      updated_diagram = Repo.get!(Diagram, diagram1.id)
      assert updated_diagram.visibility == :unlisted
    end

    test "Make Private action updates diagram visibility", %{
      conn: conn,
      diagrams: [_, _, diagram3]
    } do
      # diagram3 starts as :unlisted
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # Select the diagram
      view
      |> element("#select-input-#{diagram3.id}")
      |> render_click()

      # Click "Make Private" action
      view
      |> element("button", "Make Private")
      |> render_click()

      # Confirm the action by submitting the modal form
      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      # Verify the diagram was updated
      updated_diagram = Repo.get!(Diagram, diagram3.id)
      assert updated_diagram.visibility == :private
    end

    test "bulk action updates multiple diagrams at once", %{conn: conn, diagrams: [d1, d2, d3]} do
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # Select all diagrams using "select all" checkbox
      view
      |> element("input[aria-label='Select all items']")
      |> render_click()

      # Click "Make Public" action
      view
      |> element("button", "Make Public")
      |> render_click()

      # Confirm the action by submitting the modal form
      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      # Verify all diagrams were updated
      assert Repo.get!(Diagram, d1.id).visibility == :public
      assert Repo.get!(Diagram, d2.id).visibility == :public
      assert Repo.get!(Diagram, d3.id).visibility == :public
    end

    test "shows confirmation dialog with correct message for single item", %{
      conn: conn,
      diagrams: [diagram1 | _]
    } do
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # Select one diagram
      view
      |> element("#select-input-#{diagram1.id}")
      |> render_click()

      # Click "Make Public" action
      view
      |> element("button", "Make Public")
      |> render_click()

      # Check confirmation message
      html = render(view)
      assert html =~ "Make this diagram public?"
      assert html =~ "visible to everyone"
    end

    test "shows confirmation dialog with correct message for multiple items", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # Select all diagrams
      view
      |> element("input[aria-label='Select all items']")
      |> render_click()

      # Click "Make Public" action
      view
      |> element("button", "Make Public")
      |> render_click()

      # Check confirmation message mentions multiple items
      html = render(view)
      assert html =~ "Make 3 diagrams public?"
    end

    test "displays success flash after action completes", %{conn: conn, diagrams: [diagram1 | _]} do
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # Select and update
      view
      |> element("#select-input-#{diagram1.id}")
      |> render_click()

      view
      |> element("button", "Make Public")
      |> render_click()

      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      # Check for success flash
      html = render(view)
      assert html =~ "1 diagram(s) set to public"
    end

    test "consecutive actions update database correctly", %{conn: conn, diagrams: [diagram1 | _]} do
      # Note: Flash message propagation on consecutive actions within the same LiveView
      # session has limitations in Backpex's FormComponent due to how push_patch handles
      # flash in LiveComponents. This test verifies that the database operations succeed
      # regardless of flash display behavior.
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # First action: Make Public
      view
      |> element("#select-input-#{diagram1.id}")
      |> render_click()

      view
      |> element("button", "Make Public")
      |> render_click()

      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      html = render(view)
      assert html =~ "1 diagram(s) set to public"

      # Verify first action worked
      assert Repo.get!(Diagram, diagram1.id).visibility == :public

      # Second action: Make Private (on same diagram, same LiveView session)
      assert has_element?(view, "#select-input-#{diagram1.id}")

      view
      |> element("#select-input-#{diagram1.id}")
      |> render_click()

      assert has_element?(view, "button", "Make Private")

      view
      |> element("button", "Make Private")
      |> render_click()

      assert has_element?(view, "#action-confirm-modal")

      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      # Verify database reflects final state - this is the critical assertion
      assert Repo.get!(Diagram, diagram1.id).visibility == :private
    end

    test "multiple sequential actions update correct number of records", %{
      conn: conn,
      diagrams: [d1, d2, _d3]
    } do
      # Note: Flash message propagation on consecutive actions within the same LiveView
      # session has limitations in Backpex's FormComponent. This test verifies that bulk
      # operations correctly update the expected number of records.
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # First action: Make one diagram public
      view
      |> element("#select-input-#{d1.id}")
      |> render_click()

      view
      |> element("button", "Make Public")
      |> render_click()

      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      html = render(view)
      assert html =~ "1 diagram(s) set to public"
      assert Repo.get!(Diagram, d1.id).visibility == :public

      # Second action: Make two diagrams unlisted (same LiveView session)
      view
      |> element("#select-input-#{d1.id}")
      |> render_click()

      view
      |> element("#select-input-#{d2.id}")
      |> render_click()

      view
      |> element("button", "Make Unlisted")
      |> render_click()

      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      # Verify database state - this confirms the bulk operation worked correctly
      assert Repo.get!(Diagram, d1.id).visibility == :unlisted
      assert Repo.get!(Diagram, d2.id).visibility == :unlisted
    end

    test "different action types on different selections work correctly", %{
      conn: conn,
      diagrams: [d1, d2, d3]
    } do
      # Note: Flash message propagation on consecutive actions has limitations in Backpex.
      # This test verifies that different visibility actions correctly update the database.
      {:ok, view, _html} = live(conn, ~p"/admin/diagrams")

      # Make all public first
      view
      |> element("input[aria-label='Select all items']")
      |> render_click()

      view
      |> element("button", "Make Public")
      |> render_click()

      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      html = render(view)
      assert html =~ "3 diagram(s) set to public"

      # Verify first action
      assert Repo.get!(Diagram, d1.id).visibility == :public
      assert Repo.get!(Diagram, d2.id).visibility == :public
      assert Repo.get!(Diagram, d3.id).visibility == :public

      # Now make just one private (same LiveView session)
      view
      |> element("#select-input-#{d1.id}")
      |> render_click()

      view
      |> element("button", "Make Private")
      |> render_click()

      view
      |> form("#action-confirm-modal form")
      |> render_submit()

      # Verify database state is correct - this is the critical assertion
      assert Repo.get!(Diagram, d1.id).visibility == :private
      assert Repo.get!(Diagram, d2.id).visibility == :public
      assert Repo.get!(Diagram, d3.id).visibility == :public
    end
  end

  describe "access control for bulk visibility actions" do
    test "non-superadmin cannot access diagrams admin", %{conn: conn} do
      regular_user = fixture(:user, email: "regular@example.com")
      conn = Plug.Test.init_test_session(conn, %{user_id: regular_user.id})

      {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/admin/diagrams")

      assert flash["error"] =~ "superadmin"
    end

    test "unauthenticated user cannot access diagrams admin", %{conn: conn} do
      {:error, {:redirect, %{to: "/", flash: flash}}} = live(conn, ~p"/admin/diagrams")

      assert flash["error"] =~ "logged in"
    end
  end
end
