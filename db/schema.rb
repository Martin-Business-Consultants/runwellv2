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

ActiveRecord::Schema[8.1].define(version: 2026_10_03_100000) do
  create_table "access_tokens", force: :cascade do |t|
    t.integer "user_id"
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
    t.integer "contact_id"
    t.datetime "paused_at"
    t.index ["contact_id"], name: "index_access_tokens_on_contact_id"
    t.index ["oauth_client_id"], name: "index_access_tokens_on_oauth_client_id"
    t.index ["refresh_token_digest"], name: "index_access_tokens_on_refresh_token_digest", unique: true
    t.index ["token_digest"], name: "index_access_tokens_on_token_digest", unique: true
    t.index ["user_id"], name: "index_access_tokens_on_user_id"
  end

  create_table "action_mailbox_inbound_emails", force: :cascade do |t|
    t.integer "status", default: 0, null: false
    t.string "message_id", null: false
    t.string "message_checksum", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["message_id", "message_checksum"], name: "index_action_mailbox_inbound_emails_uniqueness", unique: true
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

  create_table "agent_calls", force: :cascade do |t|
    t.integer "access_token_id", null: false
    t.string "tool", null: false
    t.string "status", null: false
    t.string "code"
    t.string "summary"
    t.integer "duration_ms"
    t.datetime "created_at", null: false
    t.index ["access_token_id", "created_at"], name: "index_agent_calls_on_access_token_id_and_created_at"
    t.index ["access_token_id"], name: "index_agent_calls_on_access_token_id"
  end

  create_table "agent_idempotency_keys", force: :cascade do |t|
    t.integer "access_token_id", null: false
    t.string "key", null: false
    t.string "tool", null: false
    t.json "response", default: {}, null: false
    t.datetime "created_at", null: false
    t.index ["access_token_id", "key"], name: "index_agent_idempotency_keys_on_access_token_id_and_key", unique: true
    t.index ["created_at"], name: "index_agent_idempotency_keys_on_created_at"
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
    t.boolean "internal", default: false, null: false
    t.index ["name"], name: "index_clients_on_name", unique: true
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

  create_table "exports", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "state", default: "queued", null: false
    t.integer "tables_count"
    t.integer "rows_count"
    t.integer "files_count"
    t.string "error"
    t.datetime "completed_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_exports_on_user_id"
  end

  create_table "identities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "provider", null: false
    t.string "uid", null: false
    t.string "email"
    t.datetime "last_used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["provider", "uid"], name: "index_identities_on_provider_and_uid", unique: true
    t.index ["user_id"], name: "index_identities_on_user_id"
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
    t.integer "user_id"
    t.string "code_digest", null: false
    t.string "redirect_uri", null: false
    t.string "code_challenge", null: false
    t.datetime "expires_at", null: false
    t.datetime "used_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.boolean "read_only", default: false, null: false
    t.integer "contact_id"
    t.index ["code_digest"], name: "index_oauth_grants_on_code_digest", unique: true
    t.index ["contact_id"], name: "index_oauth_grants_on_contact_id"
    t.index ["oauth_client_id"], name: "index_oauth_grants_on_oauth_client_id"
    t.index ["user_id"], name: "index_oauth_grants_on_user_id"
  end

  create_table "plugin_changes", force: :cascade do |t|
    t.integer "requested_by_id"
    t.string "key"
    t.string "repo", null: false
    t.string "action", null: false
    t.string "from_version"
    t.string "to_version"
    t.string "status", default: "running", null: false
    t.text "message"
    t.datetime "finished_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["requested_by_id"], name: "index_plugin_changes_on_requested_by_id"
    t.index ["status"], name: "index_plugin_changes_on_status"
  end

  create_table "portal_sessions", force: :cascade do |t|
    t.integer "contact_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["contact_id"], name: "index_portal_sessions_on_contact_id"
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
    t.json "plugin_releases", default: {}, null: false
    t.string "app_host"
    t.string "app_protocol"
    t.string "seen_host"
    t.datetime "release_check_requested_at"
    t.string "release_check_error"
    t.json "test_email", default: {}, null: false
    t.string "requests_email"
    t.boolean "client_agent_approvals", default: true, null: false
    t.string "inbound_ingress"
    t.text "inbound_password"
    t.string "time_zone"
    t.string "smtp_address"
    t.integer "smtp_port"
    t.string "smtp_username"
    t.text "smtp_password"
    t.string "smtp_security", default: "starttls", null: false
    t.boolean "prices", default: true, null: false
    t.string "text_size", default: "default", null: false
    t.boolean "require_two_factor", default: false, null: false
    t.text "custom_css"
    t.boolean "custom_css_everywhere", default: false, null: false
  end

  create_table "sign_in_providers", force: :cascade do |t|
    t.string "key", null: false
    t.string "client_id"
    t.string "client_secret"
    t.string "tenant_id"
    t.boolean "enabled", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_sign_in_providers_on_key", unique: true
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
    t.integer "board_position", null: false
    t.index ["created_by_id"], name: "index_todos_on_created_by_id"
    t.index ["engagement_id", "status", "position"], name: "index_todos_on_engagement_id_and_status_and_position"
    t.index ["engagement_id"], name: "index_todos_on_engagement_id"
    t.index ["owner_id"], name: "index_todos_on_owner_id"
    t.index ["scope_item_id"], name: "index_todos_on_scope_item_id"
    t.index ["status", "board_position"], name: "index_todos_on_status_and_board_position"
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
    t.string "text_size"
    t.string "otp_secret"
    t.datetime "otp_enabled_at"
    t.datetime "otp_last_used_at"
    t.json "otp_recovery_codes"
    t.boolean "passwordless", default: false, null: false
    t.datetime "link_signed_in_at"
    t.index ["agent_owner_id"], name: "index_users_on_agent_owner_id", unique: true
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "access_tokens", "contacts"
  add_foreign_key "access_tokens", "users"
  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "agent_calls", "access_tokens"
  add_foreign_key "agent_idempotency_keys", "access_tokens"
  add_foreign_key "agreement_versions", "agreement_versions", column: "superseded_by_id"
  add_foreign_key "agreement_versions", "engagements"
  add_foreign_key "agreement_versions", "users", column: "sent_by_id"
  add_foreign_key "approval_links", "agreement_versions"
  add_foreign_key "approval_links", "contacts"
  add_foreign_key "approvals", "agreement_versions"
  add_foreign_key "approvals", "contacts"
  add_foreign_key "approvals", "users", column: "recorded_by_id"
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
  add_foreign_key "exports", "users"
  add_foreign_key "identities", "users"
  add_foreign_key "invitations", "users"
  add_foreign_key "invitations", "users", column: "invited_by_id"
  add_foreign_key "mentions", "users", column: "mentionee_id"
  add_foreign_key "mentions", "users", column: "mentioner_id"
  add_foreign_key "notes", "users", column: "author_id"
  add_foreign_key "notifications", "users"
  add_foreign_key "notifications", "users", column: "creator_id"
  add_foreign_key "oauth_grants", "contacts"
  add_foreign_key "oauth_grants", "oauth_clients"
  add_foreign_key "oauth_grants", "users"
  add_foreign_key "plugin_changes", "users", column: "requested_by_id"
  add_foreign_key "portal_sessions", "contacts"
  add_foreign_key "questions", "users"
  add_foreign_key "requests", "clients"
  add_foreign_key "requests", "contacts"
  add_foreign_key "requests", "users", column: "triaged_by_id"
  add_foreign_key "scope_items", "agreement_versions"
  add_foreign_key "sessions", "users"
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
