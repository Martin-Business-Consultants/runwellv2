# A record that shows up in search. Each model says what its title and text are and which
# client it belongs to; everything lands in the one :searchable index (config/search.rb).
module Searchable
  extend ActiveSupport::Concern

  # Every searchable model, for rebuilding the index (search:reindex, an import).
  MODELS = %w[Client Contact Engagement Request Todo Commitment Note Document].freeze

  # Indexed from a job after each save (ActiveSearch's ReindexJob and RemoveJob), so a save never
  # waits on the index; a new record shows in search a moment later.
  included do
    has_search index: :searchable, async: true, serializer: :to_search_document
  end

  # Rebuilds the whole index now, in this process: for search:reindex and an import, where
  # jobs would arrive late or, held as an import holds them, not at all.
  def self.reindex_all(out: nil)
    ActiveRecord::Base.connection.execute("DELETE FROM searchable_documents")
    ActiveRecord::Base.connection.execute("DELETE FROM searchable_documents_fts")

    MODELS.map(&:constantize).each do |model|
      model.find_each(&:reindex_now)
      out&.puts "Reindexed #{model.count} #{model.model_name.human.pluralize.downcase}"
    end
  end

  def reindex_now = self.class._index_reflections.each_value { it.update_now(self) }

  # Rich text fields hold HTML, so the index gets their plain text; custom field values ride along.
  def to_search_document
    content = [ Rails::HTML5::FullSanitizer.new.sanitize(search_content.to_s), try(:custom_search_text) ].compact_blank.join(" ")
    { title: search_title, content: content,
      client_id: search_client_id&.to_s, created_at: created_at }
  end

  def search_client_id = try(:client_id)
end
