module Reporting
  # The stretch a report covers, by name, so a report is bookmarkable.
  class Period
    NAMES = %w[this_month last_month this_quarter last_quarter this_year last_year].freeze

    attr_reader :name, :range

    def initialize(name)
      @name = NAMES.include?(name.to_s) ? name.to_s : "this_month"
      today = Date.current
      @range = case @name
      when "this_month" then today.all_month
      when "last_month" then today.prev_month.all_month
      when "this_quarter" then today.all_quarter
      when "last_quarter" then (today - 3.months).all_quarter
      when "this_year" then today.all_year
      when "last_year" then today.prev_year.all_year
      end
    end

    def from = range.first
    def to = range.last
    def label = name.humanize
    def self.options = NAMES.map { [ it.humanize, it ] }
  end
end
