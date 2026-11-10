class ScopeItemsController < ApplicationController
  allow_staff
  require_permission :delete_records, only: :destroy
  agent_tool :show_scope_item, on: :show, title: "Show a section", description: "A section of a piece of work (scope item) with its tasks and how delivery stands."
  agent_tool :add_scope_item, on: :create, title: "Add a section to a piece of work",
    description: "A part of what the work delivers, grouping its tasks. Tasks are then added under it (create_task with scope_item_id).",
    params: { scope_item: { description: "string!", position: "integer" } }
  agent_tool :update_scope_item, on: :update, title: "Rename or move a section",
    description: "position is 1-based among the work's sections.",
    params: { scope_item: { description: "string", position: "integer" } }
  agent_tool :remove_scope_item, on: :destroy, title: "Remove a section",
    description: "Its tasks stay on the work, under no section."

  def show
    @item = ScopeItem.includes(work: :client).find(params[:id])
    @work = @item.work
    @tasks = @item.tasks.includes(:owner, :client, :contact, :custom_values, :scope_item, work: :client, assignments: :user).order(:due_on, :position)
  end

  def create
    work = Work.find_by_ref!(params[:work_ref])
    item = work.scope_items.new(item_params)
    if item.save
      redirect_to work, notice: "#{Setting.current.term(:scope_item)} added: #{item.description}."
    else
      redirect_to work, alert: item.errors.full_messages.to_sentence
    end
  end

  def update
    item = ScopeItem.find(params[:id])
    if item.update(item_params)
      redirect_to item.work, notice: "#{Setting.current.term(:scope_item)} updated."
    else
      redirect_to item.work, alert: item.errors.full_messages.to_sentence
    end
  end

  def destroy
    item = ScopeItem.find(params[:id])
    if item.destroy
      redirect_to item.work, notice: "#{Setting.current.term(:scope_item)} removed; its #{Setting.current.term(:task, count: 2).downcase} stay on the #{Setting.current.term(:work).downcase}."
    else
      redirect_to item.work, alert: item.errors.full_messages.to_sentence
    end
  end

  private
    def current_record = @item


  def item_params
    params.expect(scope_item: %i[description position])
  end
end
