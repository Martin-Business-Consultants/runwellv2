require "test_helper"

class TodoTest < ActiveSupport::TestCase
  setup do
    @landing = engagements(:landing)
    approve!(@landing)
    @design, @build = @landing.todos.order(:id).to_a
  end

  test "status changes are recorded and completion stamped" do
    @design.update!(status: "in_progress")
    assert_equal({ "from" => "planned", "to" => "in_progress" }, @design.events.last.payload)
    @design.update!(status: "done")
    assert @design.completed_at
    @design.update!(status: "planned")
    assert_nil @design.completed_at
    assert_equal 3, @design.events.where(kind: "todo.status").count
  end

  test "positions are kept per engagement and status" do
    assert_equal [ 1, 2 ], [ @design.position, @build.position ]
    @build.move!(status: "in_progress")
    assert_equal 1, @build.reload.position
    assert_equal 1, @design.reload.position
    third = @landing.todos.create!(title: "QA")
    assert_equal 2, third.position
    third.move!(status: "planned", position: 1)
    assert_equal [ "QA", "Design and copy" ], @landing.todos.where(status: "planned").order(:position).map(&:title)
  end

  test "scope item delivery state follows its work" do
    item = @design.scope_item
    assert_equal "in_progress", item.delivery_state
    @design.update!(status: "blocked")
    assert_equal "blocked", item.reload.delivery_state
    @design.update!(status: "done")
    assert_equal "done", item.reload.delivery_state
    assert_equal "not_started", scope_items(:globex_design).delivery_state
  end

  test "overdue and open scopes" do
    @design.update!(due_on: Date.current - 1)
    @build.update!(due_on: Date.current - 1, status: "done")
    assert_equal [ @design ], Todo.overdue.to_a
    assert_equal [ @design ], Todo.open.to_a
  end

  test "client is the engagement's client" do
    assert_equal clients(:acme), @design.client
  end
end
