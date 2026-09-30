require "test_helper"

class Portal::SessionsControllerTest < ActionDispatch::IntegrationTest
  test "new" do
    get new_portal_session_path
    assert_response :success
    assert_equal "portal/sessions/new", inertia_component
  end

  test "create emails a link to a known contact" do
    assert_enqueued_email_with PortalMailer, :magic_link, params: { contact: contacts(:ann) } do
      post portal_session_path, params: { email: "Ann@Acme.example" }
    end
    assert_redirected_to new_portal_session_path
    assert_match(/on its way/, flash[:notice])
  end

  test "create answers the same for an unknown or archived address" do
    contacts(:bob).archive!
    assert_no_enqueued_emails do
      post portal_session_path, params: { email: "nobody@example.org" }
      post portal_session_path, params: { email: "bob@acme.example" }
    end
    assert_redirected_to new_portal_session_path
    assert_match(/on its way/, flash[:notice])
  end

  test "a valid token signs the contact in" do
    get portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
    assert_redirected_to portal_root_path
    assert cookies[:portal_session_id]
    assert_equal 1, contacts(:ann).portal_sessions.count
    get portal_root_path
    assert_response :success
    assert_equal "Acme Co", inertia_props.dig("portal", "client")
  end

  test "a bad token does not" do
    get portal_session_link_path("bad")
    assert_redirected_to new_portal_session_path
    assert_match(/expired/, flash[:alert])
  end

  test "destroy" do
    get portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
    delete portal_session_path
    assert_redirected_to new_portal_session_path
    assert_equal 0, contacts(:ann).portal_sessions.count
    get portal_root_path
    assert_redirected_to new_portal_session_path
  end
end
