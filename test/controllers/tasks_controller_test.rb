require "test_helper"

class TasksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = works(:landing)
    tasks_per_section!(@landing)
    @design = @landing.tasks.first
  end

  test "index in table and board views with filters" do
    get tasks_path(view: "table", owner: "any")
    assert_response :success
    assert_select "table[data-slot=table] tbody tr[data-filter-target=item]", 2
    get tasks_path(view: "board")
    assert_response :success
    assert_select ".card-columns"

    get tasks_path, as: :json
    assert_equal 2, work.size
    assert_equal "WO-1", work.first.dig("work", "ref")
    get tasks_path(work: "WO-1", owner: users(:sarah).id), as: :json
    assert_equal 0, work.size

    @design.update!(status: "done")
    get tasks_path, as: :json
    assert_equal 1, work.size
    get tasks_path(status: "all"), as: :json
    assert_equal 2, work.size
  end

  test "create on a piece of work" do
    assert_difference("Task.count") do
      post work_tasks_path(@landing), params: { task: { title: "QA pass", owner_id: users(:sarah).id, due_on: Date.current + 1 } }
    end
    task = Task.last
    assert_equal users(:sarah), task.owner
    assert_equal users(:ted), task.created_by
    assert_equal "task.created", task.events.last.kind
  end

  test "create needs a title" do
    post work_tasks_path(@landing), params: { task: { title: "" } }, headers: { "HTTP_REFERER" => work_url(@landing) }
    assert_redirected_to work_url(@landing)
    assert_match(/Title can.t be blank/, flash[:alert])
  end

  test "update status and position" do
    patch task_path(@design), params: { task: { status: "in_progress", position: 1 } }, headers: { "HTTP_REFERER" => tasks_url }
    assert_redirected_to tasks_url
    assert_equal "in_progress", @design.reload.status
    patch task_path(@design), params: { task: { status: "done" } }
    assert @design.reload.completed_at
  end

  test "destroy" do
    assert_difference("Task.count", -1) { delete task_path(@design) }
  end

  private
    def work = response.parsed_body["tasks"]
end
