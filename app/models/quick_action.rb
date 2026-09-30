# The quick action tray (bottom right, A): add a note or a document, or whatever a plugin
# registers, to the record on screen or to another one picked from a list. Notes, documents
# and plugin records are polymorphic, so each action names the record types it takes.
class QuickAction
  RECORD_TYPES = %w[Client Engagement ScopeItem Todo Request].freeze

  attr_reader :key, :label, :title, :icon, :partial, :types

  # context: turns the record on screen into one this action takes (time on a scope item
  # goes to its engagement), or nil.
  def initialize(key:, label:, icon:, partial:, title: nil, types: RECORD_TYPES, context: nil)
    @key, @label, @icon, @partial, @types, @context = key.to_s, label, icon, partial, types, context
    @title = title || "Add a #{label.downcase}"
  end

  CORE = [
    new(key: :note, label: "Note", icon: "comment", partial: "quick_actions/note"),
    new(key: :document, label: "Document", icon: "attachment", partial: "quick_actions/document")
  ].freeze

  class << self
    def all = CORE + Runwell::Plugins.enabled_quick_actions.values
    def find(key) = all.find { it.key == key.to_s } || raise(ActiveRecord::RecordNotFound)

    # A record from a quick action form ("Client:12"), only of the given types.
    def locate(value, types)
      type, id = value.to_s.split(":", 2)
      raise ActionController::BadRequest unless types.include?(type)

      type.constantize.find(id)
    end

    def value_for(record) = "#{record.class.name}:#{record.id}"

    # What a picker offers: the record on screen first, then clients, open engagements and
    # open work, limited to the given types.
    def records(current = nil, types = RECORD_TYPES)
      candidates = []
      candidates += Client.ordered.to_a if types.include?("Client")
      candidates += Engagement.open.ordered.includes(:client).to_a if types.include?("Engagement")
      candidates += Todo.open.includes(engagement: :client).order(:due_on, :id).to_a if types.include?("Todo")
      ([ current ].compact + candidates).uniq
    end
  end

  def target_for(record)
    return if record.nil?

    types.include?(record.class.name) ? record : @context&.call(record)
  end

  def records(current = nil) = self.class.records(current, types)
end
