require "test_helper"

class EngagementTest < ActiveSupport::TestCase
  setup do
    @ted = users(:ted)
    @acme = clients(:acme)
    @landing = engagements(:landing)
  end

  test "refs number per label" do
    assert_equal "WO-2", @acme.engagements.create!(label: "work_order", title: "Second").ref
    assert_equal "P-2", @acme.engagements.create!(label: "project", title: "Site").ref
    assert_equal "S-2", @acme.engagements.create!(label: "service", shape: "recurring", title: "Care").ref
    assert_equal @landing, Engagement.find_by_ref!("wo-1")
  end

  test "state is read off versions and approvals" do
    assert_equal "draft", @landing.state
    version = @landing.draft_version
    version.send!(actor: @ted)
    assert_equal "sent", @landing.reload.state
    version.decide!(decision: "approved", method: "recorded", contact: contacts(:ann), evidence: "email", recorded_by: @ted)
    assert_equal "approved", @landing.reload.state
    assert @landing.approved?
    @landing.close!(reason: "Delivered")
    assert_equal "closed", @landing.reload.state
    assert_equal "engagement.closed", @landing.events.last.kind
  end

  test "changes requested shows as such" do
    version = @landing.draft_version
    version.send!(actor: @ted)
    version.decide!(decision: "changes_requested", method: "recorded", contact: contacts(:ann), evidence: "call", comment: "Too much", recorded_by: @ted)
    assert_equal "changes_requested", @landing.reload.state
    assert_nil @landing.current_version
  end

  test "agreed amount for fixed scope adds approved change orders" do
    approve!(@landing)
    assert_equal 400_000, @landing.agreed_amount_cents
    change = @landing.draft_version!(actor: @ted, summary: "Add blog")
    assert_equal "change_order", change.kind
    change.scope_items.create!(description: "Blog", price_cents: 50_000)
    assert_equal 400_000, @landing.reload.agreed_amount_cents, "a draft changes nothing"
    change.send!(actor: @ted)
    change.decide!(decision: "approved", method: "recorded", evidence: "email", recorded_by: @ted)
    assert_equal 450_000, @landing.reload.agreed_amount_cents
    assert_equal [ "Design and copy", "Build and launch", "Blog" ], @landing.agreed_items.map(&:description)
  end

  test "agreed amount for recurring is the latest approved revision" do
    retainer = engagements(:retainer)
    approve!(retainer)
    assert_equal 45_000, retainer.agreed_amount_cents
    revision = retainer.draft_version!(actor: @ted, summary: "Price change")
    assert_equal "revision", revision.kind
    assert_equal 45_000, revision.amount_cents
    revision.update!(amount_cents: 60_000)
    revision.send!(actor: @ted)
    revision.decide!(decision: "approved", method: "recorded", evidence: "email", recorded_by: @ted)
    assert_equal 60_000, retainer.reload.agreed_amount_cents
    assert_equal 15_000, revision.price_delta_cents
  end

  test "only one draft at a time" do
    assert_raises(ArgumentError) { @landing.draft_version!(actor: @ted) }
  end

  test "needs a title and known label and shape" do
    e = @acme.engagements.new(title: "", label: "retainer", shape: "loose")
    assert_not e.valid?
    assert e.errors[:title].any?
    assert e.errors[:label].any?
    assert e.errors[:shape].any?
  end
end
