# A query across everything that includes Searchable. Terms are cleaned the way Fizzy cleans
# them, so FTS5 never sees syntax it can't parse, and results come back ranked by relevance.
#
# Fuzzy by default (the search bar, the search tool): exact matches first, then records matching
# words that start with what was typed ("acm" finds Acme) or are a typo or two from it ("clinet",
# "wbsite"). Each typed word must still match, in one of those forms. The candidate words come from
# the index's own vocabulary (Search::Vocabulary). Name resolution for agents passes fuzzy: false,
# so a near miss never stands in for the record someone named.
class Search
  HIGHLIGHT_MARKERS = [ "<mark class=\"circled-text\"><span></span>", "</mark>" ].freeze
  LIMIT = 50

  # The marked title and excerpt of a fuzzy match, read like ActiveSearch's hit.
  Hit = Data.define(:highlights) do
    def highlight(name) = highlights[name.to_sym]
  end

  attr_reader :terms

  PEOPLE_LIMIT = 5

  def initialize(terms, fuzzy: true)
    @terms = clean(terms.to_s)
    @fuzzy = fuzzy
  end

  # The team (people, not their agents) by name or email address: they aren't in the search index,
  # so a direct lookup, shown after clients, work and tasks.
  def people
    return User.none if terms.blank?

    like = "%#{User.sanitize_sql_like(terms.delete('"').downcase)}%"
    User.people.active.where("lower(name) LIKE :q OR lower(email_address) LIKE :q", q: like).order(:name).limit(PEOPLE_LIMIT)
  end

  def results
    return [] if terms.blank?

    exact = exact_results
    return exact unless @fuzzy && exact.size < LIMIT

    seen = exact.to_set { [ it.class.name, it.id.to_s ] }
    exact + fuzzy_results.reject { seen.include?([ it.class.name, it.id.to_s ]) }.first(LIMIT - exact.size)
  end

  private
    def clean(terms)
      terms = terms.gsub(/[^\w"]/, " ")
      terms = terms.delete('"') if terms.count('"').odd?
      terms.squish.presence
    end

    def exact_results
      ActiveSearch.index(:searchable)
        .search(terms)
        .highlight(title: { markers: HIGHLIGHT_MARKERS }, content: { markers: HIGHLIGHT_MARKERS, snippet: { words: 20 } })
        .limit(LIMIT)
        .results
        .to_a
    end

    def fuzzy_results
      words = terms.delete('"').downcase.split.uniq.first(6)
      vocabulary = Vocabulary.new
      groups = words.map { [ it, *vocabulary.near(it) ].uniq }
      return [] if groups.all? { it.size == 1 } # nothing beyond what the exact search tried

      match = "{title content} : " + groups.map { |group| "(#{group.map { %("#{it}") }.join(" OR ")})" }.join(" AND ")
      rows = SearchableDocument.connection.select_all(SearchableDocument.sanitize_sql_array([ <<~SQL, OPEN, CLOSE, OPEN, CLOSE, match, LIMIT ]))
        SELECT d.searchable_type, d.searchable_id,
          highlight(searchable_documents_fts, 0, ?, ?) AS title_mark,
          snippet(searchable_documents_fts, 1, ?, ?, '…', 20) AS content_mark
        FROM searchable_documents_fts
        JOIN searchable_documents d ON d.rowid = searchable_documents_fts.rowid
        WHERE searchable_documents_fts MATCH ?
        ORDER BY searchable_documents_fts.rank
        LIMIT ?
      SQL
      hydrate(rows.to_a)
    rescue ActiveRecord::StatementInvalid
      []
    end

    # FTS5 returns the indexed text as it is, so it's escaped here and only then marked.
    OPEN = "\u0002".freeze
    CLOSE = "\u0003".freeze

    def mark(text)
      return nil if text.blank?

      ERB::Util.html_escape(text).to_str.gsub(OPEN, HIGHLIGHT_MARKERS.first).gsub(CLOSE, HIGHLIGHT_MARKERS.last).html_safe
    end

    def hydrate(rows)
      records = rows.group_by { it["searchable_type"] }.flat_map do |type, of_type|
        next [] unless Searchable::MODELS.include?(type)

        type.constantize.where(id: of_type.map { it["searchable_id"] }).to_a
      end.index_by { [ it.class.name, it.id.to_s ] }

      rows.filter_map do |row|
        record = records[[ row["searchable_type"], row["searchable_id"].to_s ]] or next
        record.hit = Hit.new(highlights: { title: mark(row["title_mark"]), content: (mark(row["content_mark"]) if row["content_mark"].to_s.include?(OPEN)) })
        record
      end
    end
end
