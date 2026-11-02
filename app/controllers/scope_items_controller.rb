class ScopeItemsController < ApplicationController
  allow_staff
  agent_tool :show_scope_item, on: :show, title: "Show a section", description: "A section of an engagement (scope item) with its work and how delivery stands."
  agent_tool :add_scope_item, on: :create, title: "Add a section to an engagement",
    description: "A part of what the engagement delivers, grouping its work. Work is then added under it (create_work with scope_item_id).",
    params: { scope_item: { description: "string!", position: "integer" } }
  agent_tool :update_scope_item, on: :update, title: "Rename or move a section",
    description: "position is 1-based among the engagement's sections.",
    params: { scope_item: { description: "string", position: "integer" } }
  agent_tool :remove_scope_item, on: :destroy, title: "Remove a section",
    description: "Its work stays on the engagement, under no section."

  def show
    @item = ScopeItem.includes(engagement: :client).find(params[:id])
    @engagement = @item.engagement
    @todos = @item.todos.includes(:owner, assignments: :user).order(:due_on, :position)
  end

  def create
    engagement = Engagement.find_by_ref!(params[:engagement_ref])
    item = engagement.scope_items.new(item_params)
    if item.save
      redirect_to engagement, notice: "#{Setting.current.term(:scope_item)} added: #{item.description}."
    else
      redirect_to engagement, alert: item.errors.full_messages.to_sentence
    end
  end

  def update
    item = ScopeItem.find(params[:id])
    if item.update(item_params)
      redirect_to item.engagement, notice: "#{Setting.current.term(:scope_item)} updated."
    else
      redirect_to item.engagement, alert: item.errors.full_messages.to_sentence
    end
  end

  def destroy
    item = ScopeItem.find(params[:id])
    if item.destroy
      redirect_to item.engagement, notice: "#{Setting.current.term(:scope_item)} removed; its work stays on the engagement."
    else
      redirect_to item.engagement, alert: item.errors.full_messages.to_sentence
    end
  end

  private

  def item_params
    params.expect(scope_item: %i[description position])
  end
end
