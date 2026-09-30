require "test_helper"

class AgreementVersionTest < ActiveSupport::TestCase
  setup do
    @ted = users(:ted)
    @landing = engagements(:landing)
    @version = agreement_versions(:landing_v1)
  end

  test "send! freezes a snapshot with a hash and records events" do
    @version.send!(actor: @ted)
    assert @version.sent?
    assert_equal 400_000, @version.amount_cents
    assert_equal 0, @version.price_delta_cents
    assert_equal @ted, @version.sent_by
    assert_equal 2, @version.snapshot["items"].size
    assert_equal "Acme Co", @version.snapshot["client"]
    assert_equal Digest::SHA256.hexdigest(@version.snapshot.to_json), @version.content_hash
    assert_equal [ "agreement.sent" ], @version.events.pluck(:kind)
    assert_equal [ "agreement.sent" ], @landing.events.pluck(:kind)
  end

  test "send! refuses an empty draft and a second send" do
    empty = engagements(:globex_site).agreement_versions.create!(number: 2, kind: "change_order")
    assert_raises(ArgumentError) { empty.send!(actor: @ted) }
    @version.send!(actor: @ted)
    assert_raises(ArgumentError) { @version.send!(actor: @ted) }
  end

  test "sending a new version supersedes one still awaiting a decision" do
    @version.send!(actor: @ted)
    second = @landing.agreement_versions.create!(number: 2, kind: "initial")
    second.scope_items.create!(description: "Everything", price_cents: 300_000)
    second.send!(actor: @ted)
    assert_equal second, @version.reload.superseded_by
    assert_not @version.awaiting_decision?
    assert second.awaiting_decision?
    assert_raises(ArgumentError) { @version.decide!(decision: "approved", method: "recorded", evidence: "x", recorded_by: @ted) }
  end

  test "a sent version is immutable" do
    @version.send!(actor: @ted)
    assert_raises(ActiveRecord::ReadOnlyRecord) { @version.update!(summary: "changed") }
    assert_not @version.destroy
    assert @version.errors[:base].any?
    item = @version.scope_items.first
    assert_not item.update(price_cents: 1)
    assert_not item.destroy
    assert_not @version.scope_items.create(description: "Extra", price_cents: 1).persisted?
    assert_equal 2, @version.reload.scope_items.count
  end

  test "a draft can still change and be discarded" do
    @version.update!(summary: "Draft summary")
    @version.scope_items.first.update!(price_cents: 1)
    assert @version.destroy
    assert_nil AgreementVersion.find_by(id: @version.id)
  end

  test "approving an initial version spawns work" do
    @version.send!(actor: @ted)
    approval = @version.decide!(decision: "approved", method: "recorded", contact: contacts(:ann), evidence: "Forwarded email", recorded_by: @ted)
    assert approval.persisted?
    assert_equal "Ann Approver", approval.approver_name
    assert_equal "ann@acme.example", approval.approver_email
    assert_equal @version.content_hash, approval.content_hash
    assert @version.approved?
    assert_equal [ "Design and copy", "Build and launch" ], @landing.todos.map(&:title)
    assert_equal @version.scope_items.map(&:id), @landing.todos.map(&:scope_item_id)
    assert_includes @version.events.pluck(:kind), "agreement.approved"
    assert_includes @landing.events.pluck(:kind), "agreement.approved"
  end

  test "approving a change order adds its work" do
    approve!(@landing)
    change = @landing.draft_version!(actor: @ted)
    change.scope_items.create!(description: "Blog", price_cents: 50_000)
    change.send!(actor: @ted)
    assert_equal 50_000, change.price_delta_cents
    change.decide!(decision: "approved", method: "recorded", evidence: "email", recorded_by: @ted)
    assert_equal 3, @landing.todos.count
  end

  test "changes requested creates no work" do
    @version.send!(actor: @ted)
    @version.decide!(decision: "changes_requested", method: "recorded", evidence: "call", recorded_by: @ted)
    assert_equal 0, @landing.todos.count
    assert @version.changes_requested?
  end

  test "decide! needs a sent version and happens once" do
    assert_raises(ArgumentError) { @version.decide!(decision: "approved", method: "recorded", evidence: "x", recorded_by: @ted) }
    @version.send!(actor: @ted)
    @version.decide!(decision: "approved", method: "recorded", evidence: "x", recorded_by: @ted)
    assert_raises(ArgumentError) { @version.reload.decide!(decision: "approved", method: "recorded", evidence: "x", recorded_by: @ted) }
  end

  test "a recorded decision needs evidence" do
    @version.send!(actor: @ted)
    assert_raises(ActiveRecord::RecordInvalid) { @version.decide!(decision: "approved", method: "recorded", recorded_by: @ted) }
    assert_nil @version.reload.approval
  end

  test "approvals are immutable" do
    @version.send!(actor: @ted)
    approval = @version.decide!(decision: "approved", method: "recorded", evidence: "x", recorded_by: @ted)
    assert_raises(ActiveRecord::ReadOnlyRecord) { approval.update!(comment: "later") }
    assert_not approval.destroy
  end

  test "issue_link! makes a usable link that expires" do
    @version.send!(actor: @ted)
    link = @version.issue_link!(contacts(:ann), expires_in: 1.day)
    assert link.usable?
    travel 2.days do
      assert link.expired?
      assert_not link.usable?
    end
  end
end
