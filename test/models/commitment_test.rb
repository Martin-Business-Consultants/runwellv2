require "test_helper"

class CommitmentTest < ActiveSupport::TestCase
  setup { @acme = clients(:acme) }

  def commit(**attrs)
    @acme.commitments.create!({ description: "Do it", due_on: Date.current, owner_kind: "us", source: "test" }.merge(attrs))
  end

  test "overdue and due soon" do
    late = commit(due_on: Date.current - 1)
    soon = commit(due_on: Date.current + 3)
    far = commit(due_on: Date.current + 30)
    assert late.overdue?
    assert_equal [ late ], Commitment.overdue.to_a
    assert_equal [ soon ], Commitment.due_soon.to_a
    assert_includes Commitment.open, far
  end

  test "resolving is final and recorded" do
    c = commit
    c.resolve!("done", note: "Shipped")
    assert_equal "done", c.resolution
    assert c.resolved_at
    assert_not c.open?
    assert_equal "commitment.done", c.events.last.kind
    assert_raises(ArgumentError) { c.resolve!("missed") }
    assert_raises(ActiveRecord::ReadOnlyRecord) { c.update!(description: "Changed") }
    assert_not_includes Commitment.overdue, c
  end

  test "owner names" do
    assert_equal "Sarah Staff", commit(user: users(:sarah)).owner_name
    assert_equal "Ann Approver", commit(owner_kind: "client", contact: contacts(:ann)).owner_name
    assert_equal "Acme Co", commit(owner_kind: "client").owner_name
  end

  test "a client-side owner must belong to the client" do
    c = @acme.commitments.new(description: "x", due_on: Date.current, owner_kind: "client", contact: contacts(:gina), source: "t")
    assert_not c.valid?
    assert c.errors[:contact].any?
  end

  test "needs a date, a source and a known resolution" do
    c = @acme.commitments.new(description: "x", owner_kind: "them", resolution: "maybe")
    assert_not c.valid?
    assert c.errors[:due_on].any?
    assert c.errors[:source].any?
    assert c.errors[:owner_kind].any?
    assert c.errors[:resolution].any?
  end
end
