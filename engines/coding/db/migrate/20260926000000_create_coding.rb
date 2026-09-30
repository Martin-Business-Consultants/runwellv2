# Code, as a plugin. Repositories hang off a client, engagement or todo (polymorphic, with the
# engagement and client kept alongside so a todo inherits its engagement's repos and an
# engagement its client's). Branches tie a todo to a branch and its pull request. The rest is
# what GitHub tells us through webhooks and the nightly sync: deploys, commits, issues turned
# into requests, and who can reach each repo. The connection is one row.
class CreateCoding < ActiveRecord::Migration[8.1]
  def change
    create_table :coding_connections do |t|
      t.string :client_id
      t.text :client_secret
      t.text :access_token
      t.string :login
      t.string :oauth_state
      t.datetime :connected_at
      t.text :webhook_secret
      t.string :issue_label, null: false, default: "client"
      t.boolean :close_work_on_merge, null: false, default: true
      t.datetime :last_synced_at
      t.text :last_error
      t.timestamps
    end

    create_table :coding_repositories do |t|
      t.references :linkable, polymorphic: true, null: false
      t.references :engagement, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.references :added_by, foreign_key: { to_table: :users }
      t.string :url, null: false
      t.string :full_name
      t.string :default_branch, null: false, default: "main"
      t.string :path
      t.string :staging_url
      t.string :production_url
      t.text :setup_notes
      t.boolean :share_deploys, null: false, default: false
      t.bigint :webhook_id
      t.timestamps
    end
    add_index :coding_repositories, :full_name

    create_table :coding_branches do |t|
      t.references :todo, null: false, foreign_key: true
      t.references :repository, null: false, foreign_key: { to_table: :coding_repositories }
      t.string :name, null: false
      t.integer :pr_number
      t.string :pr_url
      t.string :pr_title
      t.string :pr_state
      t.string :checks_state
      t.boolean :review_requested, null: false, default: false
      t.datetime :merged_at
      t.timestamps
    end
    add_index :coding_branches, %i[repository_id name], unique: true

    create_table :coding_deploys do |t|
      t.references :repository, null: false, foreign_key: { to_table: :coding_repositories }
      t.bigint :github_id, null: false
      t.string :environment, null: false
      t.string :state, null: false
      t.string :sha
      t.string :ref
      t.string :url
      t.string :description
      t.datetime :deployed_at, null: false
      t.timestamps
    end
    add_index :coding_deploys, %i[repository_id github_id], unique: true

    create_table :coding_commits do |t|
      t.references :repository, null: false, foreign_key: { to_table: :coding_repositories }
      t.references :todo, foreign_key: true
      t.references :user, foreign_key: true
      t.string :sha, null: false
      t.string :author_login
      t.string :message
      t.datetime :committed_at, null: false
      t.datetime :logged_at
      t.datetime :dismissed_at
      t.timestamps
    end
    add_index :coding_commits, %i[repository_id sha], unique: true

    create_table :coding_issues do |t|
      t.references :repository, null: false, foreign_key: { to_table: :coding_repositories }
      t.references :request, foreign_key: true
      t.integer :number, null: false
      t.timestamps
    end
    add_index :coding_issues, %i[repository_id number], unique: true

    create_table :coding_collaborators do |t|
      t.references :repository, null: false, foreign_key: { to_table: :coding_repositories }
      t.string :login, null: false
      t.timestamps
    end
    add_index :coding_collaborators, %i[repository_id login], unique: true

    create_table :coding_identities do |t|
      t.references :user, null: false, foreign_key: true, index: { unique: true }
      t.string :github_login, null: false
      t.timestamps
    end
    add_index :coding_identities, :github_login, unique: true
  end
end
