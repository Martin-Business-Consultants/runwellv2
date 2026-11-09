# The Tasks list a change came from, as the page describes it (data-task-list, sent with the
# change): a piece of work's or a client's Tasks section, or the Tasks index, with its filter
# (open, done, all, or one status) and, on a piece of work, the section in focus. Says whether a
# task still belongs in it, so a task marked done can leave an Open list at once.
class Task::List
  KINDS = %w[work client index].freeze

  attr_reader :kind, :state, :item

  def self.from(attributes, task:)
    attributes = attributes.respond_to?(:permit) ? attributes.permit(:kind, :state, :item) : attributes.to_h
    new(**attributes.to_h.symbolize_keys) if attributes[:kind].to_s.in?(KINDS)
  end

  def initialize(kind:, state: nil, item: nil)
    @kind = kind.to_s
    @state = state.presence_in(Task::STATE_FILTERS + Task::STATUSES) || "open"
    @item = Task.section_focus(item)
  end

  def section? = kind.in?(%w[work client])

  def shows?(task) = keeps?(task.status)

  def keeps?(status)
    case state
    when "all" then true
    when "open" then status != "done"
    when "done" then status == "done"
    else status == state
    end
  end

  # The statuses it keeps, which the page carries (data-task-list-keeps) so the status picker can
  # fade a task moved out of them at once, without a copy of this rule in JavaScript.
  def keeps = Task::STATUSES.select { keeps?(it) }
end
