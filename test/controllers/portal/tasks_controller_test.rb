require "test_helper"

class Portal::TasksControllerTest < ActionDispatch::IntegrationTest
  test "index lists the client's visible work only" do
    tasks_per_section!(works(:landing))
    tasks_per_section!(works(:globex_site))
    works(:landing).tasks.last.update!(client_visible: false)
    contacts(:ann).update!(portal_access: true)
    get portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
    get portal_tasks_path, as: :json
    assert_response :success
    assert_equal [ "Design and copy" ], response.parsed_body["tasks"].map { it["title"] }
  end
end
