# What a client puts first (Work, ScopeItem, Task): their own order of priorities, set by dragging
# in the portal, kept in client_priority apart from the team's order (position), so a client's
# priorities and the team's working order never undo each other. One ranking per peer group (a
# client's pieces of work; a work's sections; every task shared with a client), so any list of
# them, a section's tasks or all of them, shows it, and a drop in any list puts the record just
# before the one it now sits above, or last. Unranked records follow the ranked ones, in the order
# the portal showed them before. Each move records `<subject>.prioritized` on the work (or the
# client), so the team sees it in History.
module ClientPrioritized
  extend ActiveSupport::Concern

  included do
    scope :by_client_priority, -> { order(Arel.sql("#{table_name}.client_priority IS NULL"), "#{table_name}.client_priority") }
  end

  class_methods do
    # Records already loaded, in the client's order: ranked first, then the rest as they came.
    def in_client_order(records) = records.each_with_index.sort_by { |record, index| [ record.client_priority ? 0 : 1, record.client_priority || 0, index ] }.map(&:first)
  end

  # Before `before` (a peer, or nil for last). by: the client's person who moved it.
  def prioritize!(before: nil, by: Current.contact)
    ids = client_priority_peers.by_client_priority.order(*client_priority_fallback).ids
    ids.delete(id)
    ids.insert(before && ids.index(before.id) || ids.size, id)

    transaction do
      self.class.where(id: ids).update_all("client_priority = CASE id #{ids.each_with_index.map { |peer, index| "WHEN #{peer.to_i} THEN #{index + 1}" }.join(" ")} END")
      priority_subject.record_event!("#{priority_subject.model_name.element}.prioritized", actor: by,
        source: Current.client_agent? ? "agent" : "portal",
        payload: { kind: model_name.element, id: id, name: priority_name, rank: ids.index(id) + 1, of: ids.size })
    end
    self.client_priority = ids.index(id) + 1
  end

  # Where it stands for the client ("2nd"), or nil while they haven't ordered it.
  def client_rank_label = client_priority&.ordinalize
end
