# Looks up what a person called something ("Bloom", "Priya", "the Spanish pages change order"),
# for an agent: the matching records of one kind, or of every kind, best first (Agent::Resolver).
# Most tools take the name directly; this is for checking first, or choosing among several.
class ResolutionsController < ApplicationController
  allow_staff
  agent_tool :resolve, on: :show, title: "Find the record a name refers to",
    description: "Give what the person called it (a client's name, a person, an engagement's ref or title, a todo's title…) and optionally its type. Answers the matching records, best first, with the id and record (\"Type:id\") other tools take. Most tools also accept the name in place of an id.",
    params: { q: "string!", type: Agent::Resolver.types }

  def show
    @query = params.require(:q)
    types = params[:type].presence_in(Agent::Resolver.types) ? [ params[:type] ] : Agent::Resolver.types
    @candidates = types.flat_map { Agent::Resolver.candidates(it, @query, limit: 5) }.uniq.first(15)
  end
end
