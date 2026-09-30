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
    assert_equal "approvals/show", inertia_component
    props = inertia_props
    assert props["usable"]
    assert_equal 400_000, props.dig("version", "amount_cents")
    assert_equal 2, props.dig("version", "items").size
    assert_nil props.dig("version", "items", 0, "internal_estimate")
    assert_equal "Ann Approver", props.dig("contact", "name")
    assert @link.reload.opened_at
  end

  test "approve with a typed name" do
    post approval_path(@link.token), params: { decision: "approved", approver_name: "Ann Approver", comment: "Looks good" }
    assert_redirected_to approval_path(@link.token)
    approval = @version.reload.approval
    assert_equal [ "approved", "link", "Ann Approver", "ann@acme.example", "Looks good" ],
                 [ approval.decision, approval.method, approval.approver_name, approval.approver_email, approval.comment ]
    assert_equal contacts(:ann), approval.contact
    assert_equal 1, engagements(:landing).billable_items.count
    get approval_path(@link.token)
    assert_equal "approved", inertia_props.dig("decision", "decision")
    assert_not inertia_props["usable"]
  end

  test "request changes" do
    post approval_path(@link.token), params: { decision: "changes_requested", approver_name: "Ann", comment: "Too much" }
    assert @version.reload.changes_requested?
    assert_equal 0, BillableItem.count
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
    assert_not inertia_props["usable"]
    post approval_path(@link.token), params: { decision: "approved", approver_name: "Ann" }
    assert_match(/no longer valid/, flash[:alert])
    assert_nil @version.reload.approval
  end

  test "unknown token" do
    get approval_path("nope")
    assert_response :not_found
  end
end
