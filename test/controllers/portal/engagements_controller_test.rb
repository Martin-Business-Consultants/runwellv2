require "test_helper"

class Portal::EngagementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landing = engagements(:landing)
    contacts(:ann).update!(portal_access: true)
    contacts(:bob).update!(portal_access: true)
    get portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
  end

  test "index lists only the contact's client" do
    get portal_root_path, as: :json
    assert_response :success
    assert_equal %w[S-1 WO-1], response.parsed_body["engagements"].map { it["ref"] }.sort
  end

  test "show lists sections and visible work, never internal notes" do
    @landing.update!(estimate_notes: "Two sprints, internal only")
    work_per_section!(@landing)
    @landing.todos.last.update!(client_visible: false)
    get portal_engagement_path(@landing), as: :json
    engagement = response.parsed_body["engagement"]
    assert_equal 1, engagement["work"].size
    assert_equal 2, engagement["sections"].size
    get portal_engagement_path(@landing)
    assert_select "li", text: /Design and copy/
    assert_no_match "Two sprints", response.body
  end

  test "another client's engagement is not found" do
    get portal_engagement_path(engagements(:globex_site))
    assert_response :not_found
  end

  test "signed out is redirected" do
    delete portal_session_path
    get portal_engagement_path(@landing)
    assert_redirected_to new_portal_session_path
  end
end
