# The words in the search index (FTS5's fts5vocab over searchable_documents_fts, stemmed as the
# index stores them), for the fuzzy half of Search: the ones a typed word could have meant.
class Search::Vocabulary
  PREFIX_LIMIT = 12
  TYPO_LIMIT = 8

  def initialize
    @connection = SearchableDocument.connection
    @connection.execute("CREATE VIRTUAL TABLE IF NOT EXISTS temp.searchable_vocab USING fts5vocab(main, searchable_documents_fts, row)")
  end

  # Indexed words starting with word, the most used first, and those a typo or two away (one for a
  # word of four or five letters, two from six; none shorter, where every word is a near miss).
  def near(word)
    (starting_with(word) + typos_of(word)).uniq - [ word ]
  end

  private
    def starting_with(word)
      return [] if word.length < 2

      @connection.select_values(SearchableDocument.sanitize_sql_array(
        [ "SELECT term FROM temp.searchable_vocab WHERE term >= ? AND term < ? ORDER BY doc DESC LIMIT ?", word, word + "\u{10FFFF}", PREFIX_LIMIT ]))
    end

    def typos_of(word)
      allowed = if word.length >= 6 then 2 elsif word.length >= 4 then 1 else 0 end
      return [] if allowed.zero?

      firsts = word[0, 2].chars.uniq
      candidates.filter_map do |term, docs|
        next unless firsts.include?(term[0]) && (term.length - word.length).abs <= allowed

        distance = self.class.distance(word, term)
        # The index keeps stems ("websit"), so a longer typed word is also held to the stem's length,
        # a typo stricter, and only against stems long enough not to match everything.
        if distance > allowed && term.length >= 5 && term.length < word.length
          distance = self.class.distance(word[0, term.length], term) + 1
        end
        [ term, distance, -docs ] if distance <= allowed
      end.sort_by { it[1..] }.first(TYPO_LIMIT).map(&:first)
    end

    def candidates
      @candidates ||= @connection.select_rows("SELECT term, doc FROM temp.searchable_vocab")
    end

    # Optimal string alignment: insertions, deletions, substitutions and swapped neighbours.
    def self.distance(a, b)
      rows = Array.new(a.length + 1) { |i| Array.new(b.length + 1) { |j| i.zero? ? j : (j.zero? ? i : 0) } }
      (1..a.length).each do |i|
        (1..b.length).each do |j|
          cost = a[i - 1] == b[j - 1] ? 0 : 1
          rows[i][j] = [ rows[i - 1][j] + 1, rows[i][j - 1] + 1, rows[i - 1][j - 1] + cost ].min
          rows[i][j] = [ rows[i][j], rows[i - 2][j - 2] + 1 ].min if i > 1 && j > 1 && a[i - 1] == b[j - 2] && a[i - 2] == b[j - 1]
        end
      end
      rows[a.length][b.length]
    end
end
