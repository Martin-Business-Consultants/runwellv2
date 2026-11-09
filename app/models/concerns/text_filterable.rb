# What the page filter ("/") matches on an index, across every page of it, not just the rows
# loaded so far: a model names the columns it searches (`filters_text_on`, with any associations
# they need joined), and `filter_text(q)` keeps the records where each word typed appears in one of
# them, case aside. ApplicationController#paginate applies it to every paginated list when the page
# asks with ?q=, and the Tasks board's columns do too, so a filter reaches the whole list.
module TextFilterable
  extend ActiveSupport::Concern

  MAX_WORDS = 6

  class_methods do
    def filters_text_on(*expressions, joins: [])
      @text_filter = { expressions: expressions, joins: Array(joins) }
    end

    def text_filter = @text_filter || superclass.try(:text_filter)

    def filter_text(query)
      words = query.to_s.downcase.split.uniq.first(MAX_WORDS)
      config = text_filter
      return all if words.empty? || config.nil?

      scope = config[:joins].any? ? left_joins(*config[:joins]) : all
      words.inject(scope) do |filtered, word|
        like = "%#{sanitize_sql_like(word)}%"
        filtered.where(config[:expressions].map { "lower(COALESCE(#{it}, '')) LIKE ?" }.join(" OR "), *([ like ] * config[:expressions].size))
      end
    end
  end
end
