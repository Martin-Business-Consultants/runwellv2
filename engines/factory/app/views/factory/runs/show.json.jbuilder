json.summary "#{@run.label}: #{@run.status}, “#{@run.todo.title}”#{" (#{@run.todo.engagement.ref})" if @run.todo.engagement}"
json.run do
  json.partial! "factory/runs/run", run: @run
  json.time_limit_minutes Factory::Policy.current.run_time_limit_minutes
  json.lease_minutes Factory::Policy.current.lease_minutes
  if @claimant && @run.running?
    json.task Factory::Task.new(@run, brief: @brief).to_s
    json.branch @workspace&.branch_name
    json.repositories(@workspace&.repositories || []) do |repository|
      json.extract! repository, :url, :default_branch, :path
      json.name repository.name
      json.branch @workspace.branch_for(repository)
      json.commands @workspace.clone_commands(repository)
      json.setup_notes agent_text(repository.setup_notes)
    end
  end
end
