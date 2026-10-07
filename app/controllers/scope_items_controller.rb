class ScopeItemsController < ApplicationController
  allow_staff
  agent_tool :show_scope_item, on: :show, title: "Show a scope item", description: "A scope item with its work and how delivery stands."
  agent_tool :add_scope_item, on: :create, title: "Add a scope item to a draft",
    description: "A line of what we agreed, on a draft agreement version. The internal estimate never reaches the client.",
    params: { scope_item: { description: "string!", price_cents: "integer", internal_estimate: "string" } }
  agent_tool :update_scope_item, on: :update, title: "Change a scope item on a draft",
    params: { scope_item: { description: "string", price_cents: "integer", internal_estimate: "string" } }
  agent_tool :remove_scope_item, on: :destroy, title: "Remove a scope item from a draft"

  def show
    @item = ScopeItem.includes(agreement_version: { engagement: :client }).find(params[:id])
    @engagement = @item.engagement
    @todos = @item.todos.includes(:owner, assignments: :user).order(:due_on, :position)
  end

  def create
    version = AgreementVersion.find(params[:agreement_version_id])
    item = version.scope_items.new(item_params)
    if item.save
      redirect_to version.engagement, notice: "Item added."
    else
      redirect_to version.engagement, alert: item.errors.full_messages.to_sentence
    end
  end

  def update
    item = ScopeItem.find(params[:id])
    if item.update(item_params)
      redirect_to item.agreement_version.engagement, notice: "Item updated."
    else
      redirect_to item.agreement_version.engagement, alert: item.errors.full_messages.to_sentence
    end
  end

  def destroy
    item = ScopeItem.find(params[:id])
    if item.destroy
      redirect_to item.agreement_version.engagement, notice: "Item removed."
    else
      redirect_to item.agreement_version.engagement, alert: item.errors.full_messages.to_sentence
    end
  end

  private

  def item_params
    params.expect(scope_item: %i[description internal_estimate price_cents])
  end
end
