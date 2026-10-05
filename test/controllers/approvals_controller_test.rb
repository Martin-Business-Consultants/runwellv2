require "test_helper"

class ApprovalsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @version = agreement_versions(:landing_v1)
    @version.send!(actor: users(:ted))
    @link = @version.issue_link!(contacts(:ann))
  end

  test "show renders the snapshot and marks the link opened" do
    get approval_path(@link.token)
    assert_response :success
    assert_select "form[action=?]", approval_path(@link.token)
    assert_select "strong", text: "$4,000.00"
    assert_select "li", text: /Design and copy/
    assert_select "li", text: /Build and launch/
    assert_no_match "3 days", response.body
    assert_select "p", text: /Prepared for Ann Approver/
    assert @link.reload.opened_at
  end

  test "approve with a typed name" do
    post approval_path(@link.token), params: { decision: "approved", approver_name: "Ann Approver", comment: "Looks good" }
    assert_redirected_to approval_path(@link.token)
    approval = @version.reload.approval
    assert_equal [ "approved", "link", "Ann Approver", "ann@acme.example", "Looks good" ],
                 [ approval.decision, approval.method, approval.approver_name, approval.approver_email, approval.comment ]
    assert_equal contacts(:ann), approval.contact
    assert_equal 2, engagements(:landing).todos.count
    get approval_path(@link.token)
    assert_match "Approved", response.body
    assert_select "form[action=?]", approval_path(@link.token), count: 0
  end

  test "request changes" do
    post approval_path(@link.token), params: { decision: "changes_requested", approver_name: "Ann", comment: "Too much" }
    assert @version.reload.changes_requested?
    assert_equal 0, engagements(:landing).todos.count
  end

  test "refuses a blank name" do
    post approval_path(@link.token), params: { decision: "approved", approver_name: " " }
    assert_redirected_to approval_path(@link.token)
    assert_match(/type your name/, flash[:alert])
    assert_nil @version.reload.approval
  end

  test "refuses after a decision" do
    @version.decide!(decision: "approved", method: "recorded", evidence: "x", recorded_by: users(:ted))
    post approval_path(@link.token), params: { decision: "changes_requested", approver_name: "Ann" }
    assert_match(/no longer valid/, flash[:alert])
    assert @version.reload.approved?
  end

  test "refuses an expired link" do
    @link.update!(expires_at: 1.minute.ago)
    get approval_path(@link.token)
    assert_match "no longer valid", response.body
    assert_select "form[action=?]", approval_path(@link.token), count: 0
    post approval_path(@link.token), params: { decision: "approved", approver_name: "Ann" }
    assert_match(/no longer valid/, flash[:alert])
    assert_nil @version.reload.approval
  end

  test "unknown token" do
    get approval_path("nope")
    assert_response :not_found
  end
end
