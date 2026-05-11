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

ActiveRecord::Schema[8.1].define(version: 2026_05_11_000000) do
  enable_extension "pgcrypto"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "categories", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "updater_id", null: false
    t.index ["name"], name: "index_categories_on_name", unique: true
  end

  create_table "comment_votes", primary_key: ["user_id", "comment_id"], force: :cascade do |t|
    t.bigint "comment_id", null: false
    t.datetime "created_at", null: false
    t.bigint "user_id", null: false
    t.integer "value", null: false
    t.index ["user_id", "comment_id"], name: "index_comment_votes_on_user_id_and_comment_id"
  end

  create_table "comments", force: :cascade do |t|
    t.text "content"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.datetime "deleted_at"
    t.bigint "prompt_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "updater_id", null: false
    t.integer "votes_score", default: 0
    t.index ["creator_id"], name: "index_comments_on_creator_id"
    t.index ["prompt_id", "creator_id"], name: "index_comments_on_prompt_id_and_creator_id", unique: true
    t.index ["prompt_id"], name: "index_comments_on_prompt_id"
  end

  create_table "favorites", primary_key: ["user_id", "prompt_id"], force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "prompt_id", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "prompt_id"], name: "index_favorites_on_user_id_and_prompt_id"
  end

  create_table "help_blocks", force: :cascade do |t|
    t.text "body", null: false
    t.integer "column_span", default: 1, null: false
    t.integer "column_start", default: 1, null: false
    t.datetime "created_at", null: false
    t.integer "row_span", default: 1, null: false
    t.integer "row_start", default: 1, null: false
    t.string "style_variant", default: "card", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["row_start", "column_start"], name: "index_help_blocks_on_row_start_and_column_start"
    t.index ["uuid"], name: "index_help_blocks_on_uuid", unique: true
  end

  create_table "help_guide_drafts", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.text "payload", default: "{\"blocks\":[]}", null: false
    t.datetime "published_at"
    t.datetime "saved_at"
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_help_guide_drafts_on_key", unique: true
  end

  create_table "prompt_tags", primary_key: ["prompt_id", "tag_id"], force: :cascade do |t|
    t.bigint "prompt_id", null: false
    t.bigint "tag_id", null: false
    t.index ["prompt_id", "tag_id"], name: "index_prompt_tags_on_prompt_id_and_tag_id"
  end

  create_table "prompt_teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.bigint "prompt_id", null: false
    t.bigint "team_id", null: false
    t.datetime "updated_at", null: false
    t.index ["creator_id"], name: "index_prompt_teams_on_creator_id"
    t.index ["prompt_id", "team_id"], name: "index_prompt_teams_on_prompt_id_and_team_id", unique: true
    t.index ["prompt_id"], name: "index_prompt_teams_on_prompt_id"
    t.index ["team_id"], name: "index_prompt_teams_on_team_id"
  end

  create_table "prompt_usages", id: false, force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "prompt_id", null: false
    t.bigint "user_id", null: false
    t.index ["user_id", "prompt_id"], name: "index_prompt_usages_on_user_id_and_prompt_id"
  end

  create_table "prompts", force: :cascade do |t|
    t.bigint "category_id", null: false
    t.text "content", null: false
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.text "description", null: false
    t.integer "favorites_count", default: 0
    t.boolean "is_anonymous", default: false
    t.bigint "pinned_comment_id"
    t.string "title"
    t.datetime "updated_at", null: false
    t.bigint "updater_id", null: false
    t.integer "uses_count", default: 0
    t.string "uuid", null: false
    t.string "visibility"
    t.index ["category_id"], name: "index_prompts_on_category_id"
    t.index ["pinned_comment_id"], name: "index_prompts_on_pinned_comment_id"
    t.index ["uuid"], name: "index_prompts_on_uuid", unique: true
  end

  create_table "tags", force: :cascade do |t|
    t.string "color"
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "updater_id", null: false
    t.index ["name"], name: "index_tags_on_name", unique: true
  end

  create_table "team_users", primary_key: ["team_id", "user_id"], force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "is_group_mod", default: false
    t.bigint "team_id", null: false
    t.bigint "user_id", null: false
    t.index ["team_id", "user_id"], name: "index_team_users_on_team_id_and_user_id"
  end

  create_table "teams", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "creator_id", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.bigint "updater_id", null: false
    t.string "uuid", null: false
    t.index ["name"], name: "index_teams_on_name", unique: true
    t.index ["uuid"], name: "index_teams_on_uuid", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "name"
    t.string "password_digest", limit: 255
    t.string "role", default: "user", null: false
    t.datetime "updated_at", null: false
    t.string "uuid", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["uuid"], name: "index_users_on_uuid", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "categories", "users", column: "creator_id"
  add_foreign_key "categories", "users", column: "updater_id"
  add_foreign_key "comment_votes", "comments"
  add_foreign_key "comment_votes", "users"
  add_foreign_key "comments", "prompts"
  add_foreign_key "comments", "users", column: "creator_id"
  add_foreign_key "comments", "users", column: "updater_id"
  add_foreign_key "favorites", "prompts"
  add_foreign_key "favorites", "users"
  add_foreign_key "prompt_tags", "prompts"
  add_foreign_key "prompt_tags", "tags"
  add_foreign_key "prompt_teams", "prompts"
  add_foreign_key "prompt_teams", "teams"
  add_foreign_key "prompt_teams", "users", column: "creator_id"
  add_foreign_key "prompt_usages", "prompts"
  add_foreign_key "prompt_usages", "users"
  add_foreign_key "prompts", "categories"
  add_foreign_key "prompts", "comments", column: "pinned_comment_id"
  add_foreign_key "prompts", "users", column: "creator_id"
  add_foreign_key "prompts", "users", column: "updater_id"
  add_foreign_key "tags", "users", column: "creator_id"
  add_foreign_key "tags", "users", column: "updater_id"
  add_foreign_key "team_users", "teams"
  add_foreign_key "team_users", "users"
  add_foreign_key "teams", "users", column: "creator_id"
  add_foreign_key "teams", "users", column: "updater_id"
end
