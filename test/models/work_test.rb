require "test_helper"

class WorkTest < ActiveSupport::TestCase
  setup do
    @ted = users(:ted)
    @acme = clients(:acme)
    @landing = works(:landing)
  end

  test "refs number per label" do
    assert_equal "WO-2", @acme.works.create!(label: "work_order", title: "Second").ref
    assert_equal "P-2", @acme.works.create!(label: "project", title: "Site").ref
    assert_equal "S-2", @acme.works.create!(label: "service", shape: "recurring", title: "Care").ref
    assert_equal @landing, Work.find_by_ref!("wo-1")
  end

  test "state is active until closed" do
    assert_equal "active", @landing.state
    @landing.close!(reason: "Delivered")
    assert_equal "closed", @landing.reload.state
    assert_equal "work.closed", @landing.events.last.kind
  end

  test "needs a title and known label and shape" do
    e = @acme.works.new(title: "", label: "retainer", shape: "loose")
    assert_not e.valid?
    assert e.errors[:title].any?
    assert e.errors[:label].any?
    assert e.errors[:shape].any?
  end
end
