require "test_helper"

class Portal::EngagementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landing = engagements(:landing)
    @version = @landing.draft_version
    @version.send!(actor: users(:ted))
    get portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
  end

  test "index lists only the contact's client" do
    get portal_root_path
    assert_response :success
    assert_equal %w[S-1 WO-1], inertia_props["engagements"].map { |e| e["ref"] }.sort
  end

  test "show with a pending agreement an approver can decide" do
    get portal_engagement_path(@landing)
    assert_response :success
    props = inertia_props
    assert props["can_approve"]
    assert_equal @version.id, props.dig("pending", "id")
    assert_nil props.dig("engagement", "estimate_notes")
    assert props.dig("engagement", "versions").none? { |v| v.key?("internal_estimate") }
  end

  test "show hides internal estimates on agreed items and lists visible work" do
    @version.decide!(decision: "approved", method: "recorded", evidence: "x", recorded_by: users(:ted))
    @landing.todos.last.update!(client_visible: false)
    get portal_engagement_path(@landing)
    assert_equal 1, inertia_props["todos"].size
    assert inertia_props.dig("engagement", "agreed_items").none? { |i| i.key?("internal_estimate") }
    assert_not inertia_props["can_approve"]
  end

  test "another client's engagement is not found" do
    get portal_engagement_path(engagements(:globex_site))
    assert_response :not_found
  end

  test "a contact who cannot approve sees the pending terms but no decision" do
    delete portal_session_path
    get portal_session_link_path(contacts(:bob).generate_token_for(:portal_login))
    get portal_engagement_path(@landing)
    assert_not inertia_props["can_approve"]
    assert inertia_props["pending"]
  end

  test "signed out is redirected" do
    delete portal_session_path
    get portal_engagement_path(@landing)
    assert_redirected_to new_portal_session_path
  end
end
