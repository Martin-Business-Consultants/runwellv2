require "test_helper"

class ScopeItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @landing = works(:landing)
  end

  test "create adds a section to the work" do
    assert_difference("ScopeItem.count") do
      post work_scope_items_path(@landing), params: { scope_item: { description: "QA" } }
    end
    assert_redirected_to work_path(@landing)
    assert_equal "QA", @landing.scope_items.last.description
  end

  test "create with errors" do
    assert_no_difference("ScopeItem.count") do
      post work_scope_items_path(@landing), params: { scope_item: { description: "" } }
    end
    assert_redirected_to work_path(@landing)
  end

  test "rename and remove a section, keeping its work" do
    item = scope_items(:design)
    task = @landing.tasks.create!(title: "Wireframes", scope_item: item)
    patch scope_item_path(item), params: { scope_item: { description: "Design" } }
    assert_equal "Design", item.reload.description
    delete scope_item_path(item)
    assert_not ScopeItem.exists?(item.id)
    assert_nil task.reload.scope_item_id
  end
end
