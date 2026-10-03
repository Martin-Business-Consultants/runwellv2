namespace :agent do
  desc "List every staff action with its agent tool, or why it has none"
  task coverage: :environment do
    rows = Agent::Catalogue.coverage
    width = rows.map { it.first.length }.max
    rows.each { |action, tool| puts "#{action.ljust(width)}  #{tool}" }
    missing = rows.count { it.last == "MISSING" }
    puts "\n#{rows.size} actions, #{Agent::Catalogue.all.size} tools, #{missing} missing"
    exit 1 if missing.positive?
  end

  desc "Play a project manager's, an employee's and a client's requests through the agent tools (nothing is kept)"
  task scenarios: :environment do
    exit 1 unless Runwell::AgentScenarios.new.run
  end
end
