class CreateCore < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :name, :string, null: false, default: ""
    add_column :users, :role, :string, null: false, default: "staff"

    # 1. Who we work for, and who can say yes
    create_table :clients do |t|
      t.string :name, null: false
      t.string :status, null: false, default: "active"
      t.string :website
      t.timestamps
    end
    add_index :clients, :name, unique: true

    create_table :contacts do |t|
      t.references :client, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email
      t.string :phone
      t.string :role
      t.boolean :can_approve, null: false, default: false
      t.datetime :archived_at
      t.timestamps
    end
    add_index :contacts, :email

    create_table :portal_sessions do |t|
      t.references :contact, null: false, foreign_key: true
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end

    # 2. What we agreed
    create_table :engagements do |t|
      t.references :client, null: false, foreign_key: true
      t.string :ref, null: false
      t.string :label, null: false, default: "work_order"   # project | work_order | service
      t.string :shape, null: false, default: "fixed"        # fixed | recurring
      t.string :title, null: false
      t.text :description
      t.text :estimate_notes                                 # internal only, never shown to clients
      t.datetime :closed_at
      t.string :close_reason
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :engagements, :ref, unique: true

    create_table :agreement_versions do |t|
      t.references :engagement, null: false, foreign_key: true
      t.integer :number, null: false
      t.string :kind, null: false, default: "initial"       # initial | change_order | revision | add_on
      t.string :summary
      t.text :reason
      t.string :cadence                                      # recurring only: monthly | quarterly | weekly
      t.integer :amount_cents, null: false, default: 0       # fixed: total; recurring: per period
      t.integer :price_delta_cents, null: false, default: 0
      t.json :snapshot
      t.string :content_hash
      t.datetime :sent_at
      t.references :sent_by, foreign_key: { to_table: :users }
      t.references :superseded_by, foreign_key: { to_table: :agreement_versions }
      t.timestamps
    end
    add_index :agreement_versions, [ :engagement_id, :number ], unique: true

    create_table :scope_items do |t|
      t.references :agreement_version, null: false, foreign_key: true
      t.string :description, null: false
      t.string :internal_estimate
      t.integer :price_cents, null: false, default: 0
      t.integer :position, null: false
      t.timestamps
    end

    create_table :approvals do |t|
      t.references :agreement_version, null: false, foreign_key: true, index: { unique: true }
      t.string :decision, null: false                        # approved | changes_requested
      t.references :contact, foreign_key: true
      t.string :approver_name
      t.string :approver_email
      t.text :comment
      t.string :method, null: false                          # link | recorded
      t.text :evidence
      t.string :ip_address
      t.string :user_agent
      t.string :content_hash
      t.datetime :decided_at, null: false
      t.references :recorded_by, foreign_key: { to_table: :users }
      t.timestamps
    end

    create_table :approval_links do |t|
      t.references :agreement_version, null: false, foreign_key: true
      t.references :contact, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :expires_at, null: false
      t.datetime :opened_at
      t.timestamps
    end
    add_index :approval_links, :token, unique: true

    # 3. What is happening against the agreement
    create_table :todos do |t|
      t.references :engagement, null: false, foreign_key: true
      t.references :scope_item, foreign_key: true
      t.string :title, null: false
      t.text :description
      t.string :status, null: false, default: "planned"     # planned | in_progress | blocked | done
      t.references :owner, foreign_key: { to_table: :users }
      t.date :due_on
      t.integer :position, null: false
      t.boolean :client_visible, null: false, default: true
      t.datetime :completed_at
      t.references :created_by, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :todos, [ :engagement_id, :status, :position ]

    create_table :commitments do |t|
      t.references :client, null: false, foreign_key: true
      t.references :engagement, foreign_key: true
      t.string :description, null: false
      t.string :owner_kind, null: false, default: "us"      # us | client
      t.references :user, foreign_key: true
      t.references :contact, foreign_key: true
      t.date :due_on, null: false
      t.string :resolution                                   # done | missed | dropped
      t.datetime :resolved_at
      t.text :resolution_note
      t.string :source, null: false
      t.timestamps
    end

    create_table :events do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.string :kind, null: false
      t.json :payload
      t.references :actor_user, foreign_key: { to_table: :users }
      t.string :actor                                        # label for an agent or tool
      t.string :source, null: false
      t.datetime :occurred_at, null: false
      t.datetime :created_at, null: false
    end
    add_index :events, [ :subject_type, :subject_id, :occurred_at ]

    create_table :notes do |t|
      t.string :subject_type, null: false
      t.bigint :subject_id, null: false
      t.text :body, null: false
      t.string :kind, null: false, default: "internal"      # call | meeting | email | internal
      t.datetime :occurred_at, null: false
      t.references :author, foreign_key: { to_table: :users }
      t.string :source, null: false
      t.timestamps
    end
    add_index :notes, [ :subject_type, :subject_id, :occurred_at ]

    # 4. What came in that we have not dealt with
    create_table :requests do |t|
      t.references :client, foreign_key: true
      t.references :contact, foreign_key: true
      t.string :sender_name
      t.string :sender_email
      t.string :subject, null: false
      t.text :body
      t.string :source, null: false
      t.string :status, null: false, default: "open"        # open | promoted | dismissed
      t.string :promoted_type
      t.bigint :promoted_id
      t.string :dismissed_reason
      t.datetime :received_at, null: false
      t.references :triaged_by, foreign_key: { to_table: :users }
      t.datetime :triaged_at
      t.timestamps
    end
    add_index :requests, :status

    # 5. What needs a human right now
    create_table :questions do |t|
      t.references :user, null: false, foreign_key: true
      t.text :text, null: false
      t.json :choices, null: false, default: []
      t.string :subject_type
      t.bigint :subject_id
      t.text :context
      t.string :asked_by, null: false
      t.string :source, null: false
      t.text :answer
      t.datetime :answered_at
      t.datetime :dismissed_at
      t.timestamps
    end
    add_index :questions, [ :user_id, :answered_at, :dismissed_at ]

    # Hand-off to money tools. Read-only forever; corrections are new rows.
    create_table :billable_items do |t|
      t.references :client, null: false, foreign_key: true
      t.references :engagement, null: false, foreign_key: true
      t.string :kind, null: false                            # approval | change_order | add_on | period
      t.string :description, null: false
      t.integer :amount_cents, null: false
      t.datetime :became_billable_at, null: false
      t.string :source_type
      t.bigint :source_id
      t.references :correction_of, foreign_key: { to_table: :billable_items }
      t.datetime :exported_at
      t.string :external_ref
      t.datetime :created_at, null: false
    end
    add_index :billable_items, [ :source_type, :source_id ], unique: true, where: "correction_of_id IS NULL"
  end
end
