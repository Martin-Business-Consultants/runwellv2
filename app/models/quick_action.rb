# The quick action tray (bottom right, A): add a note or a document, or whatever a plugin
# registers, to the record on screen or to another one picked from a list. Notes, documents
# and plugin records are polymorphic, so each action names the record types it takes.
class QuickAction
  RECORD_TYPES = %w[Client Engagement ScopeItem Todo Request].freeze
  STARTING = 12 # records a picker shows before anything is typed

  attr_reader :key, :label, :title, :icon, :partial, :types

  # context: turns the record on screen into one this action takes (time on a scope item
  # goes to its engagement), or nil.
  def initialize(key:, label:, icon:, partial:, title: nil, types: RECORD_TYPES, context: nil)
    @key, @label, @icon, @partial, @types, @context = key.to_s, label, icon, partial, types, context
    @title = title || "Add a #{label.downcase}"
  end

  CORE = [
    new(key: :note, label: "Note", icon: "comment", partial: "quick_actions/note"),
    new(key: :document, label: "Document", icon: "attachment", partial: "quick_actions/document"),
    # A promise with a date (p): on a client or engagement; work, a scope item or a request take
    # its engagement, or its client.
    new(key: :commitment, label: "Commitment", title: "Add a commitment", icon: "bookmark", partial: "quick_actions/commitment",
      types: %w[Client Engagement], context: ->(record) { record.try(:engagement) || record.try(:client) })
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

    # What a picker offers before anything is typed: the record on screen, then the ones changed
    # most recently, a dozen in all. Never the whole install: a page carries the picker in its
    # tray, and a large install has thousands of records (the rest are found by search).
    def records(current = nil, types = RECORD_TYPES)
      recent = types.flat_map { |type| scope_for(type).order(updated_at: :desc).limit(STARTING).to_a }
      ([ current ].compact + recent.sort_by(&:updated_at).reverse).uniq.first(STARTING)
    end

    # What a picker offers for what was typed: names, refs and titles that match (Agent::Resolver),
    # across the types it takes, closed ones included.
    def search(query, types = RECORD_TYPES)
      types.flat_map { |type| Agent::Resolver.candidates(type, query, limit: 8) }.first(20)
    end

    def scope_for(type)
      case type
      when "Client" then Client.all
      when "Engagement" then Engagement.includes(:client)
      when "Todo" then Todo.includes(engagement: :client)
      else type.constantize.all
      end
    end
  end

  def target_for(record)
    return if record.nil?

    types.include?(record.class.name) ? record : @context&.call(record)
  end

  def records(current = nil) = self.class.records(current, types)
end
