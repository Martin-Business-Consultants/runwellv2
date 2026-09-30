require "test_helper"

class Portal::ApprovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @landing = engagements(:landing)
    @version = @landing.draft_version
    @version.send!(actor: users(:ted))
  end

  test "an approver approves from the portal" do
    get portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
    post portal_engagement_approvals_path(@landing), params: { decision: "approved", approver_name: "Ann Approver", comment: "Go" }
    assert_redirected_to portal_engagement_path(@landing)
    approval = @version.reload.approval
    assert_equal [ "link", contacts(:ann), "portal" ], [ approval.method, approval.contact, @version.events.last.source ]
    assert_equal 1, @landing.billable_items.count
  end

  test "a typed name is required" do
    get portal_session_link_path(contacts(:ann).generate_token_for(:portal_login))
    post portal_engagement_approvals_path(@landing), params: { decision: "approved", approver_name: "" }
    assert_match(/type your name/, flash[:alert])
    assert_nil @version.reload.approval
  end

  test "a contact without approval rights cannot" do
    get portal_session_link_path(contacts(:bob).generate_token_for(:portal_login))
    post portal_engagement_approvals_path(@landing), params: { decision: "approved", approver_name: "Bob" }
    assert_match(/Nothing is awaiting/, flash[:alert])
    assert_nil @version.reload.approval
  end

  test "another client's contact cannot" do
    get portal_session_link_path(contacts(:gina).generate_token_for(:portal_login))
    post portal_engagement_approvals_path(@landing), params: { decision: "approved", approver_name: "Gina" }
    assert_response :not_found
  end
end
