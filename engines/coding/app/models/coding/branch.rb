module Coding
  # A todo's branch in a repo, and its pull request as GitHub last told us.
  class Branch < ::ApplicationRecord
    self.table_name = "coding_branches"

    PR_STATES = %w[draft open merged closed].freeze
    CHECK_STATES = %w[pending success failure].freeze

    belongs_to :todo, class_name: "::Todo"
    belongs_to :repository

    validates :name, presence: true, uniqueness: { scope: :repository_id }
    validates :pr_state, inclusion: { in: PR_STATES }, allow_nil: true
    validates :checks_state, inclusion: { in: CHECK_STATES }, allow_nil: true

    scope :failing, -> { where(checks_state: "failure", pr_state: %w[draft open]) }
    scope :open_prs, -> { where(pr_state: %w[draft open]) }

    class << self
      # The branch name a todo's work goes on: "p-4/58-get-contact-details".
      def name_for(todo)
        slug = todo.title.parameterize.first(40).delete_suffix("-")
        "#{todo.engagement.ref.downcase}/#{todo.id}-#{slug}"
      end

      # The todo a branch name points at when nobody recorded it: "p-4/58-…" or "58-…".
      def todo_from(name)
        id = name.to_s[%r{(?:\A|/)(\d+)-}, 1]
        ::Todo.find_by(id: id) if id
      end

      # The branch row for a name pushed to a repo, recorded or worked out from the name.
      def locate(repository, name)
        repository.branches.find_by(name: name) || todo_from(name)&.then do |todo|
          repository.branches.create!(todo: todo, name: name) if Repository.for(todo).include?(repository)
        end
      end

      # What someone reported: the branch a todo is on and its pull request, in whichever of
      # the todo's repos the pull request belongs to (the first when it doesn't say).
      def record!(todo, name:, pull_request_url: nil)
        return if name.blank? && pull_request_url.blank?

        repositories = Repository.for(todo)
        repository = repositories.find { pull_request_url.to_s.start_with?(it.web_url + "/") } || repositories.first or return
        branch = repository.branches.find_or_initialize_by(name: name.presence || name_for(todo))
        branch.todo = todo
        if pull_request_url.present?
          branch.pr_url = pull_request_url
          branch.pr_number = pull_request_url[%r{/pull/(\d+)}, 1] || branch.pr_number
          branch.pr_state ||= "open"
        end
        branch.save!
        branch
      end
    end

    def pr_label
      return "No pull request" unless pr_number

      [ "##{pr_number}", pr_state&.humanize, (checks_state && "checks #{checks_state}") ].compact.join(" · ")
    end

    def label = "#{repository.name} #{name}"
    def compare_url = repository.github? ? "#{repository.web_url}/compare/#{repository.default_branch}...#{name}?expand=1" : nil
  end
end
