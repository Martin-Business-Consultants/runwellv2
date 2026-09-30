# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_09_30_120000) do
  create_table "access_tokens", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.string "kind", default: "personal", null: false
    t.string "token_digest", null: false
    t.string "refresh_token_digest"
    t.integer "oauth_client_id"
    t.datetime "expires_at"
    t.datetime "refresh_expires_at"
    t.datetime "last_used_at"
    t.datetime "revoked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "read_only", default: false, null: false
    t.index ["oauth_client_id"], name: "index_access_tokens_on_oauth_client_id"
    t.index ["refresh_token_digest"], name: "index_access_tokens_on_refresh_token_digest", unique: true
    t.index ["token_digest"], name: "index_access_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_access_tokens_on_user_id"
  end

  create_table "account_management_accesses", force: :cascade do |t|
    t.integer "client_id", null: false
    t.integer "verified_by_id"
    t.string "platform", null: false
    t.string "name", null: false
    t.string "external_id"
    t.string "url"
    t.string "owned_by", default: "unknown", null: false
    t.string "owner_name"
    t.string "our_access", default: "none", null: false
    t.string "login_location"
    t.date "token_expires_on"
    t.date "verified_on"
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_account_management_accesses_on_client_id"
    t.index ["verified_by_id"], name: "index_account_management_accesses_on_verified_by_id"
  end

  create_table "account_management_leads", force: :cascade do |t|
    t.integer "client_id", null: false
    t.integer "user_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_account_management_leads_on_client_id", unique: true
    t.index ["user_id"], name: "index_account_management_leads_on_user_id"
  end

  create_table "account_management_meeting_items", force: :cascade do |t|
    t.integer "meeting_id", null: false
    t.integer "commitment_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["commitment_id"], name: "index_account_management_meeting_items_on_commitment_id", unique: true
    t.index ["meeting_id"], name: "index_account_management_meeting_items_on_meeting_id"
  end

  create_table "account_management_meetings", force: :cascade do |t|
    t.integer "client_id", null: false
    t.integer "engagement_id"
    t.integer "owner_id"
    t.integer "created_by_id"
    t.string "title", null: false
    t.datetime "starts_at", null: false
    t.text "agenda"
    t.datetime "agenda_sent_at"
    t.string "agenda_sent_via"
    t.text "recap"
    t.datetime "recap_sent_at"
    t.string "recap_sent_via"
    t.datetime "cancelled_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_account_management_meetings_on_client_id"
    t.index ["created_by_id"], name: "index_account_management_meetings_on_created_by_id"
    t.index ["engagement_id"], name: "index_account_management_meetings_on_engagement_id"
    t.index ["owner_id"], name: "index_account_management_meetings_on_owner_id"
    t.index ["starts_at"], name: "index_account_management_meetings_on_starts_at"
  end

  create_table "account_management_weekly_updates", force: :cascade do |t|
    t.integer "user_id", null: false
    t.date "week_of", null: false
    t.text "body"
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "week_of"], name: "index_account_management_weekly_updates_on_user_id_and_week_of", unique: true
    t.index ["user_id"], name: "index_account_management_weekly_updates_on_user_id"
  end

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "agreement_versions", force: :cascade do |t|
    t.integer "engagement_id", null: false
    t.integer "number", null: false
    t.string "kind", default: "initial", null: false
    t.string "summary"
    t.text "reason"
    t.string "cadence"
    t.integer "amount_cents", default: 0, null: false
    t.integer "price_delta_cents", default: 0, null: false
    t.json "snapshot"
    t.string "content_hash"
    t.datetime "sent_at"
    t.integer "sent_by_id"
    t.integer "superseded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["engagement_id", "number"], name: "index_agreement_versions_on_engagement_id_and_number", unique: true
    t.index ["engagement_id"], name: "index_agreement_versions_on_engagement_id"
    t.index ["sent_by_id"], name: "index_agreement_versions_on_sent_by_id"
    t.index ["superseded_by_id"], name: "index_agreement_versions_on_superseded_by_id"
  end

  create_table "approval_links", force: :cascade do |t|
    t.integer "agreement_version_id", null: false
    t.integer "contact_id", null: false
    t.string "token", null: false
    t.datetime "expires_at", null: false
    t.datetime "opened_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agreement_version_id"], name: "index_approval_links_on_agreement_version_id"
    t.index ["contact_id"], name: "index_approval_links_on_contact_id"
    t.index ["token"], name: "index_approval_links_on_token", unique: true
  end

  create_table "approvals", force: :cascade do |t|
    t.integer "agreement_version_id", null: false
    t.string "decision", null: false
    t.integer "contact_id"
    t.string "approver_name"
    t.string "approver_email"
    t.text "comment"
    t.string "method", null: false
    t.text "evidence"
    t.string "ip_address"
    t.string "user_agent"
    t.string "content_hash"
    t.datetime "decided_at", null: false
    t.integer "recorded_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agreement_version_id"], name: "index_approvals_on_agreement_version_id", unique: true
    t.index ["contact_id"], name: "index_approvals_on_contact_id"
    t.index ["recorded_by_id"], name: "index_approvals_on_recorded_by_id"
  end

  create_table "clients", force: :cascade do |t|
    t.string "name", null: false
    t.string "status", default: "active", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "time_zone"
    t.index ["name"], name: "index_clients_on_name", unique: true
  end

  create_table "coding_branches", force: :cascade do |t|
    t.integer "todo_id", null: false
    t.integer "repository_id", null: false
    t.string "name", null: false
    t.integer "pr_number"
    t.string "pr_url"
    t.string "pr_title"
    t.string "pr_state"
    t.string "checks_state"
    t.boolean "review_requested", default: false, null: false
    t.datetime "merged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "name"], name: "index_coding_branches_on_repository_id_and_name", unique: true
    t.index ["repository_id"], name: "index_coding_branches_on_repository_id"
    t.index ["todo_id"], name: "index_coding_branches_on_todo_id"
  end

  create_table "coding_collaborators", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.string "login", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "login"], name: "index_coding_collaborators_on_repository_id_and_login", unique: true
    t.index ["repository_id"], name: "index_coding_collaborators_on_repository_id"
  end

  create_table "coding_commits", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.integer "todo_id"
    t.integer "user_id"
    t.string "sha", null: false
    t.string "author_login"
    t.string "message"
    t.datetime "committed_at", null: false
    t.datetime "logged_at"
    t.datetime "dismissed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "sha"], name: "index_coding_commits_on_repository_id_and_sha", unique: true
    t.index ["repository_id"], name: "index_coding_commits_on_repository_id"
    t.index ["todo_id"], name: "index_coding_commits_on_todo_id"
    t.index ["user_id"], name: "index_coding_commits_on_user_id"
  end

  create_table "coding_connections", force: :cascade do |t|
    t.string "client_id"
    t.text "client_secret"
    t.text "access_token"
    t.string "login"
    t.string "oauth_state"
    t.datetime "connected_at"
    t.text "webhook_secret"
    t.string "issue_label", default: "client", null: false
    t.boolean "close_work_on_merge", default: true, null: false
    t.datetime "last_synced_at"
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "coding_deploys", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.bigint "github_id", null: false
    t.string "environment", null: false
    t.string "state", null: false
    t.string "sha"
    t.string "ref"
    t.string "url"
    t.string "description"
    t.datetime "deployed_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "github_id"], name: "index_coding_deploys_on_repository_id_and_github_id", unique: true
    t.index ["repository_id"], name: "index_coding_deploys_on_repository_id"
  end

  create_table "coding_identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "github_login", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["github_login"], name: "index_coding_identities_on_github_login", unique: true
    t.index ["user_id"], name: "index_coding_identities_on_user_id", unique: true
  end

  create_table "coding_issues", force: :cascade do |t|
    t.integer "repository_id", null: false
    t.integer "request_id"
    t.integer "number", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["repository_id", "number"], name: "index_coding_issues_on_repository_id_and_number", unique: true
    t.index ["repository_id"], name: "index_coding_issues_on_repository_id"
    t.index ["request_id"], name: "index_coding_issues_on_request_id"
  end

  create_table "coding_repositories", force: :cascade do |t|
    t.string "linkable_type", null: false
    t.integer "linkable_id", null: false
    t.integer "engagement_id"
    t.integer "client_id", null: false
    t.integer "added_by_id"
    t.string "url", null: false
    t.string "full_name"
    t.string "default_branch", default: "main", null: false
    t.string "path"
    t.string "staging_url"
    t.string "production_url"
    t.text "setup_notes"
    t.boolean "share_deploys", default: false, null: false
    t.bigint "webhook_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["added_by_id"], name: "index_coding_repositories_on_added_by_id"
    t.index ["client_id"], name: "index_coding_repositories_on_client_id"
    t.index ["engagement_id"], name: "index_coding_repositories_on_engagement_id"
    t.index ["full_name"], name: "index_coding_repositories_on_full_name"
    t.index ["linkable_type", "linkable_id"], name: "index_coding_repositories_on_linkable"
  end

  create_table "commitments", force: :cascade do |t|
    t.integer "client_id", null: false
    t.integer "engagement_id"
    t.string "description", null: false
    t.string "owner_kind", default: "us", null: false
    t.integer "user_id"
    t.integer "contact_id"
    t.date "due_on", null: false
    t.string "resolution"
    t.datetime "resolved_at"
    t.text "resolution_note"
    t.string "source", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_commitments_on_client_id"
    t.index ["contact_id"], name: "index_commitments_on_contact_id"
    t.index ["engagement_id"], name: "index_commitments_on_engagement_id"
    t.index ["user_id"], name: "index_commitments_on_user_id"
  end

  create_table "contacts", force: :cascade do |t|
    t.integer "client_id", null: false
    t.string "name", null: false
    t.string "email"
    t.string "phone"
    t.string "role"
    t.boolean "can_approve", default: false, null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "portal_access", default: false, null: false
    t.index ["client_id"], name: "index_contacts_on_client_id"
    t.index ["email"], name: "index_contacts_on_email"
  end

  create_table "custom_fields", force: :cascade do |t|
    t.string "model_type", null: false
    t.string "label", null: false
    t.string "key", null: false
    t.string "kind", default: "text", null: false
    t.json "choices"
    t.integer "position", null: false
    t.boolean "listed", default: false, null: false
    t.boolean "client_visible", default: false, null: false
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["model_type", "key"], name: "index_custom_fields_on_model_type_and_key", unique: true
    t.index ["model_type", "position"], name: "index_custom_fields_on_model_type_and_position"
  end

  create_table "custom_values", force: :cascade do |t|
    t.integer "custom_field_id", null: false
    t.string "subject_type", null: false
    t.integer "subject_id", null: false
    t.text "value", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["custom_field_id", "subject_type", "subject_id"], name: "index_custom_values_uniqueness", unique: true
    t.index ["custom_field_id"], name: "index_custom_values_on_custom_field_id"
    t.index ["subject_type", "subject_id"], name: "index_custom_values_on_subject"
  end

  create_table "documents", force: :cascade do |t|
    t.string "documentable_type", null: false
    t.integer "documentable_id", null: false
    t.integer "uploaded_by_id"
    t.boolean "client_visible", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["documentable_type", "documentable_id"], name: "index_documents_on_documentable"
    t.index ["uploaded_by_id"], name: "index_documents_on_uploaded_by_id"
  end

  create_table "engagements", force: :cascade do |t|
    t.integer "client_id", null: false
    t.string "ref", null: false
    t.string "label", default: "work_order", null: false
    t.string "shape", default: "fixed", null: false
    t.string "title", null: false
    t.text "description"
    t.text "estimate_notes"
    t.datetime "closed_at"
    t.string "close_reason"
    t.integer "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_engagements_on_client_id"
    t.index ["created_by_id"], name: "index_engagements_on_created_by_id"
    t.index ["ref"], name: "index_engagements_on_ref", unique: true
  end

  create_table "events", force: :cascade do |t|
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.string "kind", null: false
    t.json "payload"
    t.integer "actor_user_id"
    t.string "actor"
    t.string "source", null: false
    t.datetime "occurred_at", null: false
    t.datetime "created_at", null: false
    t.index ["actor_user_id"], name: "index_events_on_actor_user_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "index_events_on_subject_type_and_subject_id_and_occurred_at"
  end

  create_table "factory_items", force: :cascade do |t|
    t.integer "todo_id", null: false
    t.integer "engagement_id", null: false
    t.integer "client_id", null: false
    t.integer "queued_by_id"
    t.text "instructions"
    t.string "source", default: "app", null: false
    t.datetime "queued_at", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_factory_items_on_client_id"
    t.index ["engagement_id"], name: "index_factory_items_on_engagement_id"
    t.index ["queued_by_id"], name: "index_factory_items_on_queued_by_id"
    t.index ["todo_id"], name: "index_factory_items_on_todo_id", unique: true
  end

  create_table "factory_runs", force: :cascade do |t|
    t.integer "item_id"
    t.integer "todo_id", null: false
    t.integer "claimed_by_id"
    t.string "runner", null: false
    t.string "status", default: "running", null: false
    t.integer "attempt", default: 1, null: false
    t.datetime "started_at", null: false
    t.datetime "lease_expires_at", null: false
    t.datetime "heartbeat_at"
    t.datetime "finished_at"
    t.string "branch"
    t.string "pull_request_url"
    t.string "log_url"
    t.text "summary"
    t.text "error"
    t.integer "cost_cents", default: 0, null: false
    t.integer "input_tokens", default: 0, null: false
    t.integer "output_tokens", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["claimed_by_id"], name: "index_factory_runs_on_claimed_by_id"
    t.index ["item_id"], name: "index_factory_runs_on_item_id"
    t.index ["item_id"], name: "index_factory_runs_one_running_per_item", unique: true, where: "status = 'running'"
    t.index ["status"], name: "index_factory_runs_on_status"
    t.index ["todo_id"], name: "index_factory_runs_on_todo_id"
  end

  create_table "factory_settings", force: :cascade do |t|
    t.integer "max_concurrent_runs", default: 2, null: false
    t.integer "lease_minutes", default: 10, null: false
    t.integer "run_time_limit_minutes", default: 60, null: false
    t.integer "max_attempts", default: 2, null: false
    t.integer "monthly_budget_cents"
    t.boolean "queue_on_approval", default: false, null: false
    t.json "blocked_client_ids", default: [], null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "google_ads_accounts", force: :cascade do |t|
    t.string "customer_id", null: false
    t.string "descriptive_name"
    t.string "currency_code"
    t.string "status"
    t.datetime "status_changed_at"
    t.datetime "alerted_at"
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_google_ads_accounts_on_customer_id", unique: true
  end

  create_table "google_ads_connections", force: :cascade do |t|
    t.string "client_id"
    t.text "client_secret"
    t.text "developer_token"
    t.string "login_customer_id"
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "access_expires_at"
    t.datetime "connected_at"
    t.string "oauth_state"
    t.text "alert_recipients"
    t.text "last_error"
    t.datetime "last_synced_at"
    t.json "last_sync_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "google_ads_days", force: :cascade do |t|
    t.string "customer_id", null: false
    t.date "date", null: false
    t.integer "cost_cents", default: 0, null: false
    t.integer "clicks", default: 0, null: false
    t.integer "impressions", default: 0, null: false
    t.float "conversions", default: 0.0, null: false
    t.integer "conversions_value_cents", default: 0, null: false
    t.float "search_impression_share"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "date"], name: "index_google_ads_days_on_customer_id_and_date", unique: true
  end

  create_table "google_ads_links", force: :cascade do |t|
    t.integer "engagement_id", null: false
    t.string "customer_id", null: false
    t.integer "linked_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id"], name: "index_google_ads_links_on_customer_id"
    t.index ["engagement_id"], name: "index_google_ads_links_on_engagement_id", unique: true
    t.index ["linked_by_id"], name: "index_google_ads_links_on_linked_by_id"
  end

  create_table "google_ads_spends", force: :cascade do |t|
    t.string "customer_id", null: false
    t.date "month", null: false
    t.integer "cost_cents", default: 0, null: false
    t.integer "impressions", default: 0, null: false
    t.integer "clicks", default: 0, null: false
    t.float "conversions", default: 0.0, null: false
    t.string "currency_code"
    t.date "through"
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["customer_id", "month"], name: "index_google_ads_spends_on_customer_id_and_month", unique: true
  end

  create_table "invitations", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "role", default: "member", null: false
    t.integer "invited_by_id", null: false
    t.integer "user_id"
    t.datetime "sent_at", null: false
    t.datetime "accepted_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_invitations_on_email_address"
    t.index ["invited_by_id"], name: "index_invitations_on_invited_by_id"
    t.index ["user_id"], name: "index_invitations_on_user_id"
  end

  create_table "mentions", force: :cascade do |t|
    t.string "source_type", null: false
    t.integer "source_id", null: false
    t.integer "mentioner_id", null: false
    t.integer "mentionee_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["mentionee_id"], name: "index_mentions_on_mentionee_id"
    t.index ["mentioner_id"], name: "index_mentions_on_mentioner_id"
    t.index ["source_type", "source_id", "mentionee_id"], name: "index_mentions_on_source_type_and_source_id_and_mentionee_id", unique: true
    t.index ["source_type", "source_id"], name: "index_mentions_on_source"
  end

  create_table "notes", force: :cascade do |t|
    t.string "subject_type", null: false
    t.bigint "subject_id", null: false
    t.text "body", null: false
    t.string "kind", default: "internal", null: false
    t.datetime "occurred_at", null: false
    t.integer "author_id"
    t.string "source", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["author_id"], name: "index_notes_on_author_id"
    t.index ["subject_type", "subject_id", "occurred_at"], name: "index_notes_on_subject_type_and_subject_id_and_occurred_at"
  end

  create_table "notifications", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "creator_id", null: false
    t.string "source_type", null: false
    t.integer "source_id", null: false
    t.datetime "read_at"
    t.integer "unread_count", default: 0, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_notifications_on_creator_id"
    t.index ["source_type", "source_id"], name: "index_notifications_on_source"
    t.index ["user_id", "read_at", "updated_at"], name: "index_notifications_on_user_id_and_read_at_and_updated_at"
    t.index ["user_id"], name: "index_notifications_on_user_id"
  end

  create_table "oauth_clients", force: :cascade do |t|
    t.string "uid", null: false
    t.string "name", null: false
    t.json "redirect_uris", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["uid"], name: "index_oauth_clients_on_uid", unique: true
  end

  create_table "oauth_grants", force: :cascade do |t|
    t.integer "oauth_client_id", null: false
    t.integer "user_id", null: false
    t.string "code_digest", null: false
    t.string "redirect_uri", null: false
    t.string "code_challenge", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "read_only", default: false, null: false
    t.index ["code_digest"], name: "index_oauth_grants_on_code_digest", unique: true
    t.index ["oauth_client_id"], name: "index_oauth_grants_on_oauth_client_id"
    t.index ["user_id"], name: "index_oauth_grants_on_user_id"
  end

  create_table "outsend_connections", force: :cascade do |t|
    t.text "api_key"
    t.datetime "last_delivered_at"
    t.integer "delivered_count", default: 0, null: false
    t.text "last_error"
    t.datetime "last_error_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "portal_sessions", force: :cascade do |t|
    t.integer "contact_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_portal_sessions_on_contact_id"
  end

  create_table "qa_checks", force: :cascade do |t|
    t.integer "client_id", null: false
    t.integer "engagement_id"
    t.integer "owner_id"
    t.integer "created_by_id"
    t.string "name", null: false
    t.string "kind", default: "other", null: false
    t.string "url"
    t.boolean "live", default: false, null: false
    t.integer "every_days", default: 7, null: false
    t.text "instructions"
    t.string "report_token", null: false
    t.datetime "retest_after"
    t.datetime "archived_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_qa_checks_on_client_id"
    t.index ["created_by_id"], name: "index_qa_checks_on_created_by_id"
    t.index ["engagement_id"], name: "index_qa_checks_on_engagement_id"
    t.index ["owner_id"], name: "index_qa_checks_on_owner_id"
    t.index ["report_token"], name: "index_qa_checks_on_report_token", unique: true
  end

  create_table "qa_expectations", force: :cascade do |t|
    t.integer "check_id", null: false
    t.integer "approved_by_id"
    t.string "key", null: false
    t.string "label", null: false
    t.text "expected"
    t.string "match", default: "is", null: false
    t.string "note"
    t.date "expires_on"
    t.integer "position", default: 0, null: false
    t.datetime "approved_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["approved_by_id"], name: "index_qa_expectations_on_approved_by_id"
    t.index ["check_id", "key"], name: "index_qa_expectations_on_check_id_and_key", unique: true
    t.index ["check_id"], name: "index_qa_expectations_on_check_id"
  end

  create_table "qa_gates", force: :cascade do |t|
    t.integer "todo_id", null: false
    t.integer "check_id", null: false
    t.integer "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["check_id"], name: "index_qa_gates_on_check_id"
    t.index ["created_by_id"], name: "index_qa_gates_on_created_by_id"
    t.index ["todo_id", "check_id"], name: "index_qa_gates_on_todo_id_and_check_id", unique: true
    t.index ["todo_id"], name: "index_qa_gates_on_todo_id"
  end

  create_table "qa_issues", force: :cascade do |t|
    t.integer "client_id", null: false
    t.integer "engagement_id"
    t.integer "todo_id"
    t.integer "check_id"
    t.integer "expectation_id"
    t.integer "run_id"
    t.integer "opened_by_id"
    t.integer "assignee_id"
    t.integer "fixed_by_id"
    t.integer "verified_by_id"
    t.integer "verified_by_run_id"
    t.string "title", null: false
    t.string "url"
    t.text "steps"
    t.text "expected"
    t.text "actual"
    t.string "environment"
    t.boolean "found_live", default: false, null: false
    t.string "source", default: "app", null: false
    t.string "root_cause"
    t.text "fix_note"
    t.datetime "fixed_at"
    t.datetime "verified_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["assignee_id"], name: "index_qa_issues_on_assignee_id"
    t.index ["check_id"], name: "index_qa_issues_on_check_id"
    t.index ["client_id"], name: "index_qa_issues_on_client_id"
    t.index ["engagement_id"], name: "index_qa_issues_on_engagement_id"
    t.index ["expectation_id"], name: "index_qa_issues_on_expectation_id"
    t.index ["fixed_by_id"], name: "index_qa_issues_on_fixed_by_id"
    t.index ["opened_by_id"], name: "index_qa_issues_on_opened_by_id"
    t.index ["run_id"], name: "index_qa_issues_on_run_id"
    t.index ["todo_id"], name: "index_qa_issues_on_todo_id"
    t.index ["verified_by_id"], name: "index_qa_issues_on_verified_by_id"
    t.index ["verified_by_run_id"], name: "index_qa_issues_on_verified_by_run_id"
  end

  create_table "qa_results", force: :cascade do |t|
    t.integer "run_id", null: false
    t.integer "expectation_id"
    t.string "key", null: false
    t.string "label", null: false
    t.text "expected"
    t.text "actual"
    t.boolean "passed", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["expectation_id"], name: "index_qa_results_on_expectation_id"
    t.index ["run_id"], name: "index_qa_results_on_run_id"
  end

  create_table "qa_runs", force: :cascade do |t|
    t.integer "check_id", null: false
    t.integer "user_id"
    t.string "source", null: false
    t.string "reporter"
    t.string "status", null: false
    t.text "notes"
    t.string "evidence_url"
    t.integer "http_status"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["check_id", "created_at"], name: "index_qa_runs_on_check_id_and_created_at"
    t.index ["check_id"], name: "index_qa_runs_on_check_id"
    t.index ["user_id"], name: "index_qa_runs_on_user_id"
  end

  create_table "questions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.text "text", null: false
    t.json "choices", default: [], null: false
    t.string "subject_type"
    t.bigint "subject_id"
    t.text "context"
    t.string "asked_by", null: false
    t.string "source", null: false
    t.text "answer"
    t.datetime "answered_at"
    t.datetime "dismissed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id", "answered_at", "dismissed_at"], name: "index_questions_on_user_id_and_answered_at_and_dismissed_at"
    t.index ["user_id"], name: "index_questions_on_user_id"
  end

  create_table "quickbooks_billing_plans", force: :cascade do |t|
    t.integer "engagement_id", null: false
    t.integer "contact_id"
    t.integer "deposit_invoice_id"
    t.integer "balance_invoice_id"
    t.boolean "send_balance_on_close", default: false, null: false
    t.text "last_error"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["balance_invoice_id"], name: "index_quickbooks_billing_plans_on_balance_invoice_id"
    t.index ["contact_id"], name: "index_quickbooks_billing_plans_on_contact_id"
    t.index ["deposit_invoice_id"], name: "index_quickbooks_billing_plans_on_deposit_invoice_id"
    t.index ["engagement_id"], name: "index_quickbooks_billing_plans_on_engagement_id", unique: true
  end

  create_table "quickbooks_connections", force: :cascade do |t|
    t.string "client_id"
    t.text "client_secret"
    t.string "environment", default: "production", null: false
    t.string "realm_id"
    t.string "company_name"
    t.text "access_token"
    t.text "refresh_token"
    t.datetime "access_expires_at"
    t.datetime "refresh_expires_at"
    t.string "oauth_state"
    t.datetime "connected_at"
    t.string "default_item_id"
    t.string "default_item_name"
    t.datetime "last_synced_at"
    t.text "last_error"
    t.json "last_sync_summary"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "quickbooks_customers", force: :cascade do |t|
    t.integer "client_id", null: false
    t.string "qbo_id", null: false
    t.string "display_name"
    t.string "email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_quickbooks_customers_on_client_id", unique: true
    t.index ["qbo_id"], name: "index_quickbooks_customers_on_qbo_id", unique: true
  end

  create_table "quickbooks_invoices", force: :cascade do |t|
    t.string "qbo_id", null: false
    t.integer "client_id", null: false
    t.integer "engagement_id"
    t.integer "created_by_id"
    t.string "kind", default: "other", null: false
    t.string "doc_number"
    t.date "txn_date"
    t.date "due_on"
    t.integer "total_cents", default: 0, null: false
    t.integer "balance_cents", default: 0, null: false
    t.boolean "voided", default: false, null: false
    t.text "payment_link"
    t.string "sent_to"
    t.datetime "sent_at"
    t.string "sync_token"
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_quickbooks_invoices_on_client_id"
    t.index ["created_by_id"], name: "index_quickbooks_invoices_on_created_by_id"
    t.index ["engagement_id"], name: "index_quickbooks_invoices_on_engagement_id"
    t.index ["qbo_id"], name: "index_quickbooks_invoices_on_qbo_id", unique: true
  end

  create_table "quickbooks_payments", force: :cascade do |t|
    t.string "qbo_id", null: false
    t.integer "invoice_id", null: false
    t.integer "amount_cents", null: false
    t.date "paid_on", null: false
    t.string "method_name"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_quickbooks_payments_on_invoice_id"
    t.index ["qbo_id"], name: "index_quickbooks_payments_on_qbo_id", unique: true
  end

  create_table "quickbooks_recurring_links", force: :cascade do |t|
    t.integer "engagement_id", null: false
    t.integer "contact_id"
    t.string "qbo_id", null: false
    t.string "sync_token"
    t.string "name"
    t.integer "amount_cents"
    t.string "interval_type"
    t.integer "num_interval"
    t.boolean "active", default: true, null: false
    t.date "next_on"
    t.string "drift"
    t.datetime "pushed_at"
    t.datetime "synced_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_quickbooks_recurring_links_on_contact_id"
    t.index ["engagement_id"], name: "index_quickbooks_recurring_links_on_engagement_id", unique: true
  end

  create_table "requests", force: :cascade do |t|
    t.integer "client_id"
    t.integer "contact_id"
    t.string "sender_name"
    t.string "sender_email"
    t.string "subject", null: false
    t.text "body"
    t.string "source", null: false
    t.string "status", default: "open", null: false
    t.string "promoted_type"
    t.bigint "promoted_id"
    t.string "dismissed_reason"
    t.datetime "received_at", null: false
    t.integer "triaged_by_id"
    t.datetime "triaged_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_requests_on_client_id"
    t.index ["contact_id"], name: "index_requests_on_contact_id"
    t.index ["status"], name: "index_requests_on_status"
    t.index ["triaged_by_id"], name: "index_requests_on_triaged_by_id"
  end

  create_table "scope_items", force: :cascade do |t|
    t.integer "agreement_version_id", null: false
    t.string "description", null: false
    t.string "internal_estimate"
    t.integer "price_cents", default: 0, null: false
    t.integer "position", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["agreement_version_id"], name: "index_scope_items_on_agreement_version_id"
  end

  create_table "searchable_documents", force: :cascade do |t|
    t.string "searchable_type", null: false
    t.string "searchable_id", null: false
    t.string "client_id"
    t.datetime "created_at"
    t.index ["searchable_type", "searchable_id"], name: "idx_on_searchable_type_searchable_id_be150b479a", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "settings", force: :cascade do |t|
    t.json "terminology", default: {}, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.json "plugin_states", default: {}, null: false
    t.string "index_view", default: "cards", null: false
    t.string "theme", default: "system", null: false
    t.string "radius", default: "fizzy", null: false
    t.string "scheme", default: "fizzy", null: false
    t.string "font", default: "system", null: false
    t.datetime "setup_dismissed_at"
    t.string "mail_from_name"
    t.string "mail_from_email"
    t.json "latest_release", default: {}, null: false
    t.datetime "release_checked_at"
  end

  create_table "time_tracking_entries", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "engagement_id"
    t.integer "minutes", null: false
    t.date "worked_on", null: false
    t.string "note"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "trackable_type"
    t.integer "trackable_id"
    t.integer "client_id"
    t.index ["client_id"], name: "index_time_tracking_entries_on_client_id"
    t.index ["engagement_id"], name: "index_time_tracking_entries_on_engagement_id"
    t.index ["trackable_type", "trackable_id"], name: "index_time_tracking_entries_on_trackable"
    t.index ["user_id"], name: "index_time_tracking_entries_on_user_id"
  end

  create_table "todos", force: :cascade do |t|
    t.integer "engagement_id", null: false
    t.integer "scope_item_id"
    t.string "title", null: false
    t.text "description"
    t.string "status", default: "planned", null: false
    t.integer "owner_id"
    t.date "due_on"
    t.integer "position", null: false
    t.boolean "client_visible", default: true, null: false
    t.datetime "completed_at"
    t.integer "created_by_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_by_id"], name: "index_todos_on_created_by_id"
    t.index ["engagement_id", "status", "position"], name: "index_todos_on_engagement_id_and_status_and_position"
    t.index ["engagement_id"], name: "index_todos_on_engagement_id"
    t.index ["owner_id"], name: "index_todos_on_owner_id"
    t.index ["scope_item_id"], name: "index_todos_on_scope_item_id"
  end

  create_table "upgrades", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "external_id"
    t.string "external_url"
    t.datetime "finished_at"
    t.string "from_version", null: false
    t.text "message"
    t.integer "requested_by_id", null: false
    t.string "status", default: "running", null: false
    t.string "to_version", null: false
    t.datetime "updated_at", null: false
    t.string "via", null: false
    t.index ["requested_by_id"], name: "index_upgrades_on_requested_by_id"
    t.index ["status"], name: "index_upgrades_on_status"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "name", default: "", null: false
    t.string "role", default: "member", null: false
    t.datetime "deactivated_at"
    t.integer "agent_owner_id"
    t.index ["agent_owner_id"], name: "index_users_on_agent_owner_id", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "access_tokens", "users"
  add_foreign_key "account_management_accesses", "clients"
  add_foreign_key "account_management_accesses", "users", column: "verified_by_id"
  add_foreign_key "account_management_leads", "clients"
  add_foreign_key "account_management_leads", "users"
  add_foreign_key "account_management_meeting_items", "account_management_meetings", column: "meeting_id"
  add_foreign_key "account_management_meeting_items", "commitments", on_delete: :cascade
  add_foreign_key "account_management_meetings", "clients"
  add_foreign_key "account_management_meetings", "engagements"
  add_foreign_key "account_management_meetings", "users", column: "created_by_id"
  add_foreign_key "account_management_meetings", "users", column: "owner_id"
  add_foreign_key "account_management_weekly_updates", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agreement_versions", "agreement_versions", column: "superseded_by_id"
  add_foreign_key "agreement_versions", "engagements"
  add_foreign_key "agreement_versions", "users", column: "sent_by_id"
  add_foreign_key "approval_links", "agreement_versions"
  add_foreign_key "approval_links", "contacts"
  add_foreign_key "approvals", "agreement_versions"
  add_foreign_key "approvals", "contacts"
  add_foreign_key "approvals", "users", column: "recorded_by_id"
  add_foreign_key "coding_branches", "coding_repositories", column: "repository_id"
  add_foreign_key "coding_branches", "todos"
  add_foreign_key "coding_collaborators", "coding_repositories", column: "repository_id"
  add_foreign_key "coding_commits", "coding_repositories", column: "repository_id"
  add_foreign_key "coding_commits", "todos"
  add_foreign_key "coding_commits", "users"
  add_foreign_key "coding_deploys", "coding_repositories", column: "repository_id"
  add_foreign_key "coding_identities", "users"
  add_foreign_key "coding_issues", "coding_repositories", column: "repository_id"
  add_foreign_key "coding_issues", "requests"
  add_foreign_key "coding_repositories", "clients"
  add_foreign_key "coding_repositories", "engagements"
  add_foreign_key "coding_repositories", "users", column: "added_by_id"
  add_foreign_key "commitments", "clients"
  add_foreign_key "commitments", "contacts"
  add_foreign_key "commitments", "engagements"
  add_foreign_key "commitments", "users"
  add_foreign_key "contacts", "clients"
  add_foreign_key "custom_values", "custom_fields"
  add_foreign_key "documents", "users", column: "uploaded_by_id"
  add_foreign_key "engagements", "clients"
  add_foreign_key "engagements", "users", column: "created_by_id"
  add_foreign_key "events", "users", column: "actor_user_id"
  add_foreign_key "factory_items", "clients"
  add_foreign_key "factory_items", "engagements"
  add_foreign_key "factory_items", "todos"
  add_foreign_key "factory_items", "users", column: "queued_by_id"
  add_foreign_key "factory_runs", "factory_items", column: "item_id", on_delete: :nullify
  add_foreign_key "factory_runs", "todos"
  add_foreign_key "factory_runs", "users", column: "claimed_by_id"
  add_foreign_key "invitations", "users"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "mentions", "users", column: "mentionee_id"
  add_foreign_key "mentions", "users", column: "mentioner_id"
  add_foreign_key "notes", "users", column: "author_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "creator_id"
  add_foreign_key "oauth_grants", "oauth_clients"
  add_foreign_key "oauth_grants", "users"
  add_foreign_key "portal_sessions", "contacts"
  add_foreign_key "qa_checks", "clients"
  add_foreign_key "qa_checks", "engagements"
  add_foreign_key "qa_checks", "users", column: "created_by_id"
  add_foreign_key "qa_checks", "users", column: "owner_id"
  add_foreign_key "qa_expectations", "qa_checks", column: "check_id"
  add_foreign_key "qa_expectations", "users", column: "approved_by_id"
  add_foreign_key "qa_gates", "qa_checks", column: "check_id"
  add_foreign_key "qa_gates", "todos"
  add_foreign_key "qa_gates", "users", column: "created_by_id"
  add_foreign_key "qa_issues", "clients"
  add_foreign_key "qa_issues", "engagements"
  add_foreign_key "qa_issues", "qa_checks", column: "check_id"
  add_foreign_key "qa_issues", "qa_expectations", column: "expectation_id", on_delete: :nullify
  add_foreign_key "qa_issues", "qa_runs", column: "run_id"
  add_foreign_key "qa_issues", "qa_runs", column: "verified_by_run_id"
  add_foreign_key "qa_issues", "todos"
  add_foreign_key "qa_issues", "users", column: "assignee_id"
  add_foreign_key "qa_issues", "users", column: "fixed_by_id"
  add_foreign_key "qa_issues", "users", column: "opened_by_id"
  add_foreign_key "qa_issues", "users", column: "verified_by_id"
  add_foreign_key "qa_results", "qa_expectations", column: "expectation_id", on_delete: :nullify
  add_foreign_key "qa_results", "qa_runs", column: "run_id"
  add_foreign_key "qa_runs", "qa_checks", column: "check_id"
  add_foreign_key "qa_runs", "users"
  add_foreign_key "questions", "users"
  add_foreign_key "quickbooks_billing_plans", "contacts"
  add_foreign_key "quickbooks_billing_plans", "engagements"
  add_foreign_key "quickbooks_billing_plans", "quickbooks_invoices", column: "balance_invoice_id"
  add_foreign_key "quickbooks_billing_plans", "quickbooks_invoices", column: "deposit_invoice_id"
  add_foreign_key "quickbooks_customers", "clients"
  add_foreign_key "quickbooks_invoices", "clients"
  add_foreign_key "quickbooks_invoices", "engagements"
  add_foreign_key "quickbooks_invoices", "users", column: "created_by_id"
  add_foreign_key "quickbooks_payments", "quickbooks_invoices", column: "invoice_id"
  add_foreign_key "quickbooks_recurring_links", "contacts"
  add_foreign_key "quickbooks_recurring_links", "engagements"
  add_foreign_key "requests", "clients"
  add_foreign_key "requests", "contacts"
  add_foreign_key "requests", "users", column: "triaged_by_id"
  add_foreign_key "scope_items", "agreement_versions"
  add_foreign_key "sessions", "users"
  add_foreign_key "time_tracking_entries", "clients"
  add_foreign_key "time_tracking_entries", "engagements"
  add_foreign_key "time_tracking_entries", "users"
  add_foreign_key "todos", "engagements"
  add_foreign_key "todos", "scope_items"
  add_foreign_key "todos", "users", column: "created_by_id"
  add_foreign_key "todos", "users", column: "owner_id"
  add_foreign_key "upgrades", "users", column: "requested_by_id"
  add_foreign_key "users", "users", column: "agent_owner_id"

  # Virtual tables defined in this database.
  # Note that virtual tables may not work with other database engines. Be careful if changing database.
  create_virtual_table "searchable_documents_fts", "fts5", ["title", "content", "tokenize='porter'"]
end
