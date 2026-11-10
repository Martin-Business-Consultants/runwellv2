require "test_helper"

class Portal::WorksControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landing = works(:landing)
    contacts(:ann).update!(portal_access: true)
    contacts(:bob).update!(portal_access: true)
    post portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
  end

  test "index lists only the contact's client" do
    get portal_root_path, as: :json
    assert_response :success
    assert_equal %w[S-1 WO-1], response.parsed_body["works"].map { it["ref"] }.sort
  end

  test "show lists sections and visible work" do
    tasks_per_section!(@landing)
    @landing.tasks.last.update!(client_visible: false)
    get portal_work_path(@landing), as: :json
    work = response.parsed_body["work"]
    assert_equal 1, work["tasks"].size
    assert_equal 2, work["sections"].size
    get portal_work_path(@landing)
    assert_select "li", text: /Design and copy/
    assert_no_match "Two sprints", response.body
  end

  test "another client's work is not found" do
    get portal_work_path(works(:globex_site))
    assert_response :not_found
  end

  test "signed out is redirected" do
    delete portal_session_path
    get portal_work_path(@landing)
    assert_redirected_to new_portal_session_path
  end
end
