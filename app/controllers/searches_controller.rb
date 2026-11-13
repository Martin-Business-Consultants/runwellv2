class SearchesController < ApplicationController
  allow_staff
  agent_tool :search, on: :show, title: "Search everything",
    description: "Full-text search across clients, contacts, work, tasks (requests too), notes and documents, ranked by relevance.",
    params: { q: "string!" }

  def show
    @query = params[:q].presence
    @search = Search.new(@query)
    # The search palette (layouts/shared/_search) asks as you type: its items, not the page.
    if request.headers["Runeui-Command"].present?
      render partial: "searches/palette", locals: { results: @search.results, query: @query, people: @search.people }
    end
  end
end
