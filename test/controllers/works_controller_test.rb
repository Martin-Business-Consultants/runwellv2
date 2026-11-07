require "test_helper"

class WorksControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = works(:landing)
  end

  test "index filters by state and label" do
    @landing.close!
    get works_path(state: "open"), as: :json
    assert_equal %w[P-1 S-1], work_refs.sort
    get works_path(state: "closed"), as: :json
    assert_equal %w[WO-1], work_refs
    get works_path(state: "all", label: "service"), as: :json
    assert_equal %w[S-1], work_refs
  end

  test "show" do
    tasks_per_section!(@landing)
    get work_path(@landing)
    assert_response :success
    assert_select "h1.page-title", "WO-1 Spring landing page"
    assert_select ".record-meta", /Active/
    assert_select "#tasks .task-group > ul > li", 2
    assert_select ".scope-nav__item", 3

    get work_path(@landing, item: scope_items(:design).id)
    assert_select ".task-focus__title", "Design and copy"
    assert_select "#tasks .task-group > ul > li", 1
  end

  test "show by ref is case-insensitive and 404s otherwise" do
    get work_path("wo-1")
    assert_response :success
    get work_path("WO-99")
    assert_response :not_found
  end

  test "new" do
    get new_work_path(client_id: clients(:acme).id, label: "project")
    assert_response :success
    assert_select "select[name='work[label]'] option[selected][value=project]"
    assert_select "select[name='work[client_id]'] option[selected][value='#{clients(:acme).id}']"
  end

  test "create starts an active work" do
    assert_difference("Work.count") do
      post works_path, params: { work: { client_id: clients(:acme).id, label: "project", title: "Rebrand" } }
    end
    work = Work.last
    assert_redirected_to work_path(work)
    assert_equal "P-2", work.ref
    assert_equal "active", work.state
    assert_equal "work.created", work.events.first.kind
  end

  test "create with errors" do
    assert_no_difference "Work.count" do
      post works_path, params: { work: { client_id: clients(:acme).id, label: "project", title: "" } }
    end
    assert_response :unprocessable_entity
    assert_match(/Title can.t be blank/, response.body)
  end

  test "update" do
    patch work_path(@landing), params: { work: { title: "Spring page", client_id: clients(:globex).id } }
    assert_redirected_to work_path(@landing)
    assert_equal "Spring page", @landing.reload.title
    assert_equal clients(:acme), @landing.client, "client cannot be moved"
  end

  test "close" do
    post close_work_path(@landing), params: { reason: "Delivered" }
    assert_redirected_to work_path(@landing)
    assert @landing.reload.closed?
    assert_equal "Delivered", @landing.close_reason
  end

  private
    def work_refs = response.parsed_body["works"].map { |e| e["ref"] }
end
