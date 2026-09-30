require "test_helper"

class Portal::RequestsControllerTest < ActionDispatch::IntegrationTest
  setup { get portal_session_link_path(contacts(:bob).generate_token_for(:portal_login)) }

  test "new" do
    get new_portal_request_path
    assert_response :success
  end

  test "create logs a request from the portal" do
    assert_difference("Request.count") do
      post portal_requests_path, params: { request: { subject: "Add a newsletter", body: "Please" } }
    end
    r = Request.last
    assert_redirected_to portal_root_path
    assert_equal [ clients(:acme), contacts(:bob), "portal", "bob@acme.example", "open" ],
                 [ r.client, r.contact, r.source, r.sender_email, r.status ]
    event = r.events.last
    assert_equal [ "request.received", "portal", "Bob Requester" ], [ event.kind, event.source, event.actor_name ]
  end

  test "create with errors" do
    post portal_requests_path, params: { request: { subject: "" } }
    assert_redirected_to new_portal_request_path
    follow_redirect!
    assert inertia_props["errors"]["subject"].present?
  end
end
