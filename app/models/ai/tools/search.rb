# Finds records by words, across everything the person can see.
class Ai::Tools::Search < Ai::Tool
  description "Search Runwell (clients, contacts, engagements, work, requests, notes, commitments) by words. Answers matching records, each with its record ref (\"Type:id\") to read with read_record."
  parameter :query, description: "The words to look for"

  def self.tool_name = "search"

  def execute(query:)
    Ai.trim Ai.run_tool(user, Agent::Catalogue.find("search"), { "q" => query })
  end
end
