require "test_helper"

class Portal::TodosControllerTest < ActionDispatch::IntegrationTest
  test "index lists the client's visible work only" do
    approve!(engagements(:landing))
    approve!(engagements(:globex_site))
    engagements(:landing).todos.last.update!(client_visible: false)
    get portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
    get portal_todos_path
    assert_response :success
    assert_equal [ "Design and copy" ], inertia_props["todos"].map { |t| t["title"] }
  end
end
