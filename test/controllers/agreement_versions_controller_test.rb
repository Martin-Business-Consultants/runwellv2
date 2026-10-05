require "test_helper"

class AgreementVersionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = engagements(:landing)
    @version = agreement_versions(:landing_v1)
  end

  test "send_out with a contact freezes the draft and emails a link" do
    assert_enqueued_emails 1 do
      post send_out_agreement_version_path(@version), params: { contact_id: contacts(:ann).id }
    end
    assert_redirected_to engagement_path(@landing)
    assert @version.reload.sent?
    link = @version.approval_links.sole
    assert_equal contacts(:ann), link.contact
    assert_includes @version.events.pluck(:kind), "agreement.emailed"
  end

  test "send_out without a contact just freezes" do
    assert_no_enqueued_emails do
      post send_out_agreement_version_path(@version)
    end
    assert @version.reload.sent?
    assert_equal 0, @version.approval_links.count
  end

  test "send_out an empty draft explains" do
    post send_out_agreement_version_path(agreement_versions(:globex_v1).tap { |v| v.scope_items.destroy_all })
    assert_redirected_to engagement_path(engagements(:globex_site))
    assert_match(/at least one item/, flash[:alert])
  end

  test "issue_link emails another link" do
    @version.send!(actor: users(:ted))
    assert_enqueued_emails 1 do
      post issue_link_agreement_version_path(@version), params: { contact_id: contacts(:ann).id }
    end
    assert_equal 1, @version.approval_links.count
  end

  test "record_decision approves" do
    @version.send!(actor: users(:ted))
    post record_decision_agreement_version_path(@version), params: {
      decision: "approved", contact_id: contacts(:ann).id, evidence: "Forwarded email from Ann", comment: "Go"
    }
    assert_redirected_to engagement_path(@landing)
    assert @version.reload.approved?
    assert_equal "recorded", @version.approval.method
    assert_equal users(:ted), @version.approval.recorded_by
    assert_equal 2, @landing.todos.count
  end

  test "record_decision without evidence explains" do
    @version.send!(actor: users(:ted))
    post record_decision_agreement_version_path(@version), params: { decision: "approved" }
    assert_redirected_to engagement_path(@landing)
    assert_match(/Evidence/, flash[:alert])
    assert_nil @version.reload.approval
  end

  test "record_decision on a draft explains" do
    post record_decision_agreement_version_path(@version), params: { decision: "approved", evidence: "x" }
    assert_match(/not sent/, flash[:alert])
  end

  test "create drafts a change order after approval" do
    approve!(@landing)
    assert_difference("AgreementVersion.count") do
      post engagement_agreement_versions_path(@landing), params: { summary: "Add blog", reason: "Client asked" }
    end
    draft = @landing.reload.draft_version
    assert_equal "change_order", draft.kind
    assert_equal "Add blog", draft.summary
  end

  test "create refuses a second draft" do
    assert_no_difference("AgreementVersion.count") do
      post engagement_agreement_versions_path(@landing)
    end
    assert_match(/already open/, flash[:alert])
  end

  test "update a draft" do
    patch agreement_version_path(@version), params: { agreement_version: { summary: "Spring page v1" } }
    assert_redirected_to engagement_path(@landing)
    assert_equal "Spring page v1", @version.reload.summary
  end

  test "update a sent version is refused" do
    @version.send!(actor: users(:ted))
    patch agreement_version_path(@version), params: { agreement_version: { summary: "Changed" } }
    assert_redirected_to engagement_path(@landing)
    assert_match(/no longer change/, flash[:alert])
    assert_nil @version.reload.summary
  end

  test "destroy a draft" do
    assert_difference("AgreementVersion.count", -1) do
      delete agreement_version_path(@version)
    end
    assert_redirected_to engagement_path(@landing)
  end

  test "destroy a sent version is refused" do
    @version.send!(actor: users(:ted))
    assert_no_difference("AgreementVersion.count") do
      delete agreement_version_path(@version)
    end
    assert_match(/cannot be deleted/, flash[:alert])
  end
end
