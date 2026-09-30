# A record that shows up in search. Each model says what its title and text are and which
# client it belongs to; everything lands in the one :searchable index (config/search.rb).
module Searchable
  extend ActiveSupport::Concern

  included do
    has_search index: :searchable, async: false, serializer: :to_search_document
  end

  # Rich text fields hold HTML, so the index gets their plain text; custom field values ride along.
  def to_search_document
    content = [ Rails::HTML5::FullSanitizer.new.sanitize(search_content.to_s), try(:custom_search_text) ].compact_blank.join(" ")
    { title: search_title, content: content,
      client_id: search_client_id&.to_s, created_at: created_at }
  end

  def search_client_id = try(:client_id)
end
