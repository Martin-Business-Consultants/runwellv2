require "test_helper"

class TodosControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = engagements(:landing)
    approve!(@landing)
    @design = @landing.todos.first
  end

  test "index in table and board views with filters" do
    get todos_path(view: "table")
    assert_response :success
    assert_select "table.data-table tbody tr[data-filter-target=item]", 2
    get todos_path(view: "board")
    assert_response :success
    assert_select ".card-columns"

    get todos_path, as: :json
    assert_equal 2, work.size
    assert_equal "WO-1", work.first.dig("engagement", "ref")
    get todos_path(engagement: "WO-1", owner: users(:sarah).id), as: :json
    assert_equal 0, work.size

    @design.update!(status: "done")
    get todos_path, as: :json
    assert_equal 1, work.size
    get todos_path(status: "all"), as: :json
    assert_equal 2, work.size
  end

  test "create on an engagement" do
    assert_difference("Todo.count") do
      post engagement_todos_path(@landing), params: { todo: { title: "QA pass", owner_id: users(:sarah).id, due_on: Date.current + 1 } }
    end
    todo = Todo.last
    assert_equal users(:sarah), todo.owner
    assert_equal users(:ted), todo.created_by
    assert_equal "todo.created", todo.events.last.kind
  end

  test "create needs a title" do
    post engagement_todos_path(@landing), params: { todo: { title: "" } }, headers: { "HTTP_REFERER" => engagement_url(@landing) }
    assert_redirected_to engagement_url(@landing)
    assert_match(/Title can.t be blank/, flash[:alert])
  end

  test "update status and position" do
    patch todo_path(@design), params: { todo: { status: "in_progress", position: 1 } }, headers: { "HTTP_REFERER" => todos_url }
    assert_redirected_to todos_url
    assert_equal "in_progress", @design.reload.status
    patch todo_path(@design), params: { todo: { status: "done" } }
    assert @design.reload.completed_at
  end

  test "destroy" do
    assert_difference("Todo.count", -1) { delete todo_path(@design) }
  end

  private
    def work = response.parsed_body["work"]
end
