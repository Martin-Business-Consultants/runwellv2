# A query across everything that includes Searchable. Terms are cleaned the way Fizzy cleans
# them, so FTS5 never sees syntax it can't parse, and results come back ranked by relevance.
class Search
  HIGHLIGHT_MARKERS = [ "<mark class=\"circled-text\"><span></span>", "</mark>" ].freeze
  LIMIT = 50

  attr_reader :terms

  def initialize(terms)
    @terms = clean(terms.to_s)
  end

  def results
    return [] if terms.blank?

    ActiveSearch.index(:searchable)
      .search(terms)
      .highlight(title: { markers: HIGHLIGHT_MARKERS }, content: { markers: HIGHLIGHT_MARKERS, snippet: { words: 20 } })
      .limit(LIMIT)
      .results
  end

  private

  def clean(terms)
    terms = terms.gsub(/[^\w"]/, " ")
    terms = terms.delete('"') if terms.count('"').odd?
    terms.squish.presence
  end
end
