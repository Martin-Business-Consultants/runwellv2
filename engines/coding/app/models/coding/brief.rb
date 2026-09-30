module Coding
  # The Code plugin's section of a todo's AI brief (Runwell::Plugins.agent_brief): where the
  # code is, how to get it onto this machine on the right branch, setup notes, and the Code
  # tools for reporting back.
  module Brief
    def self.call(todo, base_url)
      workspace = Workspace.new(todo)
      repositories = workspace.repositories.to_a
      return if repositories.empty?

      repos = repositories.map do |repository|
        setup = repository.setup_notes.present? ? "\n\nSetup notes:\n\n#{ActionText::Content.new(repository.setup_notes).to_plain_text.strip}" : ""
        envs = [ ("staging #{repository.staging_url}" if repository.staging_url.present?), ("production #{repository.production_url}" if repository.production_url.present?) ].compact
        <<~MD.strip
          ### #{repository.name}

          ```sh
          #{workspace.clone_commands(repository).join("\n")}
          ```
          #{"\nEnvironments: #{envs.join(" · ")}" if envs.any?}#{setup}
        MD
      end

      <<~MD.strip
        ## Code

        Work on the branch `#{workspace.branch_name}` (open a pull request from it; Runwell follows its checks and merge).

        #{repos.join("\n\n")}

        Report back with the Code tools as well:

        ```sh
        runwell checkout_work --todo_id #{todo.id}          # this context again, as data
        runwell log_progress --todo_id #{todo.id} --progress.note "What changed" --progress.status in_progress
        runwell finish_work --todo_id #{todo.id} --completion.summary "What was done" --completion.pull_request_url <url>   # puts it in review
        runwell flag_out_of_scope --todo_id #{todo.id} --scope_flag.summary "What goes beyond the agreed scope"
        ```
      MD
    end
  end
end
