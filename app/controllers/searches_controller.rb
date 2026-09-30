class SearchesController < ApplicationController
  allow_staff
  agent_tool :search, on: :show, title: "Search everything",
    description: "Full-text search across clients, contacts, engagements, work, requests, commitments, notes and documents, ranked by relevance.",
    params: { q: "string!" }

  def show
    @query = params[:q].presence
    @search = Search.new(@query)
  end
end
