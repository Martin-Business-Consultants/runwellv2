require "test_helper"

class ScopeItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as(users(:ted))
    @version = agreement_versions(:landing_v1)
  end

  test "create takes the price in cents" do
    assert_difference("ScopeItem.count") do
      post agreement_version_scope_items_path(@version), params: { scope_item: { description: "QA", price_cents: 150_000, internal_estimate: "1 day" } }
    end
    item = @version.scope_items.last
    assert_equal 150_000, item.price_cents
    assert_equal 3, item.position
    assert_redirected_to engagement_path(engagements(:landing))
  end

  test "create needs a description" do
    assert_no_difference("ScopeItem.count") do
      post agreement_version_scope_items_path(@version), params: { scope_item: { description: "", price_cents: 100 } }
    end
    assert_redirected_to engagement_path(engagements(:landing))
    assert_match(/Description/, flash[:alert])
  end

  test "update and destroy a draft item" do
    item = scope_items(:design)
    patch scope_item_path(item), params: { scope_item: { price_cents: 200_050 } }
    assert_equal 200_050, item.reload.price_cents
    delete scope_item_path(item)
    assert_nil ScopeItem.find_by(id: item.id)
  end

  test "a sent version's items are refused" do
    @version.send!(actor: users(:ted))
    assert_no_difference("ScopeItem.count") do
      post agreement_version_scope_items_path(@version), params: { scope_item: { description: "Late", price_cents: 100 } }
    end
    patch scope_item_path(scope_items(:design)), params: { scope_item: { price_cents: 100 } }
    assert_match(/immutable/, flash[:alert])
    assert_equal 150_000, scope_items(:design).reload.price_cents
    delete scope_item_path(scope_items(:design))
    assert ScopeItem.exists?(scope_items(:design).id)
  end
end
