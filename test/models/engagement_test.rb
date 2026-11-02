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

  test "state is active until closed" do
    assert_equal "active", @landing.state
    @landing.close!(reason: "Delivered")
    assert_equal "closed", @landing.reload.state
    assert_equal "engagement.closed", @landing.events.last.kind
  end

  test "needs a title and known label and shape" do
    e = @acme.engagements.new(title: "", label: "retainer", shape: "loose")
    assert_not e.valid?
    assert e.errors[:title].any?
    assert e.errors[:label].any?
    assert e.errors[:shape].any?
  end
end
