module Coding
  # A git repository linked to a client, engagement or todo. Any remote works (GitHub, GitLab,
  # Bitbucket, your own); GitHub ones also get pull requests, checks, deploys and issues once
  # Settings > Code is connected. A todo with no repo of its own uses its engagement's, and an
  # engagement its client's, so most repos are linked once, high up. Never holds secrets: the
  # setup notes say where they live.
  class Repository < ::ApplicationRecord
    self.table_name = "coding_repositories"

    LINKABLE_TYPES = %w[Client Engagement Todo].freeze
    GITHUB = %r{\A(?:https?://github\.com/|git@github\.com:|ssh://git@github\.com/)([\w.-]+/[\w.-]+?)(?:\.git)?/?\z}

    belongs_to :linkable, polymorphic: true
    belongs_to :engagement, class_name: "::Engagement", optional: true
    belongs_to :client, class_name: "::Client"
    belongs_to :added_by, class_name: "::User", optional: true
    has_many :branches, dependent: :destroy
    has_many :deploys, dependent: :destroy
    has_many :commits, dependent: :destroy
    has_many :issues, dependent: :destroy
    has_many :collaborators, dependent: :destroy

    normalizes :url, :staging_url, :production_url, :path, with: ->(value) { value.to_s.strip.presence }
    normalizes :default_branch, with: ->(value) { value.to_s.strip.presence || "main" }

    validates :linkable_type, inclusion: { in: LINKABLE_TYPES }
    validates :url, presence: true, format: { with: %r{\A(?:https?://|ssh://|git@)\S+\z}, message: "should be a git remote, like https://github.com/agency/site or git@github.com:agency/site.git" }
    validates :url, uniqueness: { scope: %i[linkable_type linkable_id], message: "is already linked here" }
    validates :staging_url, :production_url, format: { with: %r{\Ahttps?://\S+\z}, message: "should start with https://" }, allow_nil: true

    before_validation :fill_in_context
    before_validation { self.full_name = url.to_s[GITHUB, 1] }

    scope :github, -> { where.not(full_name: nil) }
    scope :ordered, -> { order(:created_at) }

    class << self
      # The repos a record works in: its own, or the nearest ones above it.
      def for(record)
        candidates(record).lazy.map { |owner| where(linkable: owner).ordered.to_a }.find(&:any?) || []
      end

      # Where the repos in .for came from, or nil when there are none.
      def source_for(record) = candidates(record).find { where(linkable: it).exists? }

      # Repos on a scope item go to its engagement, on a request to its client.
      def linkable_for(record)
        LINKABLE_TYPES.include?(record.class.name) ? record : record.try(:engagement) || record.try(:client)
      end

      def find_by_full_name(name) = github.where("lower(full_name) = ?", name.to_s.downcase)

      private
        def candidates(record)
          case record
          when ::Todo then [ record, record.engagement, record.engagement.client ]
          when ::Engagement then [ record, record.client ]
          when ::Client then [ record ]
          else []
          end
        end
    end

    def github? = full_name.present?
    def name = full_name || url.split(%r{[/:]}).last.to_s.delete_suffix(".git")
    def label = name
    def web_url = github? ? "https://github.com/#{full_name}" : url.sub(/\Agit@([^:]+):/, 'https://\1/').delete_suffix(".git")

    def linked_label
      case linkable
      when ::Todo then linkable.title
      when ::Engagement then "#{linkable.ref} #{linkable.title}"
      when ::Client then linkable.name
      end
    end

    # Engagements whose timeline hears about this repo: the one it's on, or every open one of
    # its client when it's linked to the client.
    def engagements
      engagement ? [ engagement ] : client.engagements.open.to_a
    end

    def deletable_by?(user) = added_by == user || user.can?(:delete_records)

    def latest_deploys = deploys.where(id: deploys.group(:environment).select("max(id)")).order(:environment)

    private
      def fill_in_context
        case linkable
        when ::Todo
          self.engagement = linkable.engagement
          self.client_id = linkable.engagement.client_id
        when ::Engagement
          self.engagement = linkable
          self.client_id = linkable.client_id
        when ::Client
          self.engagement = nil
          self.client = linkable
        end
      end
  end
end
