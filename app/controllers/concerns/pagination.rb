# A page of a list, by ?page=: @page for the view (table_pagination, table_next_page_row, the
# board's columns) and its records for the action. Plain limit and offset, the same size every
# page. The method's name and @page's answers are geared_pagination's, which this replaced in 7.1,
# so plugins that paged with it keep working (docs/plugin-contract.md).
module Pagination
  extend ActiveSupport::Concern

  PER_PAGE = 25

  # Sets @page from ?page= and returns its records.
  def set_page_and_extract_portion_from(records, per_page: PER_PAGE)
    @page = Page.new(records, number: params[:page], per_page: per_page)
    @page.records
  end

  # One page of records (a relation or an array): which it is, its records, and how many there are
  # in all. A number past the end is an empty page; anything that isn't a number is the first.
  class Page
    attr_reader :number, :per_page

    def initialize(records, number: 1, per_page: PER_PAGE)
      @all = records
      @per_page = per_page
      @number = [ number.to_i, 1 ].max
    end

    def records
      @records ||= @all.is_a?(Array) ? Array(@all[offset, per_page]) : @all.limit(per_page).offset(offset)
    end

    def records_count
      @records_count ||= @all.is_a?(Array) ? @all.size : @all.unscope(:order).count(:all)
    end

    def page_count = [ (records_count.to_f / per_page).ceil, 1 ].max
    def first? = number == 1
    def last? = number >= page_count
    def before_last? = !last?
    def next_param = number + 1

    # geared_pagination's page answered its counts through its recordset.
    def recordset = self

    private
      def offset = (number - 1) * per_page
  end
end
