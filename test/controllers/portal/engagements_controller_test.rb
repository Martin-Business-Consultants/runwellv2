require "test_helper"

class Portal::EngagementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landing = engagements(:landing)
    @version = @landing.draft_version
    @version.send!(actor: users(:ted))
    contacts(:ann).update!(portal_access: true)
    contacts(:bob).update!(portal_access: true)
    get portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
  end

  test "index lists only the contact's client" do
    get portal_root_path, as: :json
    assert_response :success
    assert_equal %w[S-1 WO-1], response.parsed_body["engagements"].map { it["ref"] }.sort
  end

  test "show with a pending agreement an approver can decide" do
    @landing.update!(estimate_notes: "Two sprints, internal only")
    get portal_engagement_path(@landing)
    assert_response :success
    assert_select "form[action=?]", portal_engagement_approvals_path(@landing)
    assert_select "li", text: /Design and copy/
    assert_no_match "Two sprints", response.body
    assert_no_match "3 days", response.body
  end

  test "show hides internal estimates on agreed items and lists visible work" do
    @version.decide!(decision: "approved", method: "recorded", evidence: "x", recorded_by: users(:ted))
    @landing.todos.last.update!(client_visible: false)
    get portal_engagement_path(@landing), as: :json
    engagement = response.parsed_body["engagement"]
    assert_equal 1, engagement["work"].size
    assert_equal 2, engagement["scope_in_force"].size
    assert engagement["scope_in_force"].none? { it.key?("internal_estimate") }
    assert_nil engagement["awaiting_your_decision"]
    get portal_engagement_path(@landing)
    assert_no_match "3 days", response.body
    assert_select "form[action=?]", portal_engagement_approvals_path(@landing), count: 0
  end

  test "another client's engagement is not found" do
    get portal_engagement_path(engagements(:globex_site))
    assert_response :not_found
  end

  test "a contact who cannot approve sees the pending terms but no decision" do
    delete portal_session_path
    get portal_session_link_path(contacts(:bob).generate_token_for(:portal_login))
    get portal_engagement_path(@landing)
    assert_select "h2", text: "Awaiting your decision"
    assert_select "li", text: /Design and copy/
    assert_select "form[action=?]", portal_engagement_approvals_path(@landing), count: 0
  end

  test "signed out is redirected" do
    delete portal_session_path
    get portal_engagement_path(@landing)
    assert_redirected_to new_portal_session_path
  end
end
