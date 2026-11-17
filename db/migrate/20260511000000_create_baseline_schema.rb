class CreateBaselineSchema < ActiveRecord::Migration[8.1]
  def change
    enable_extension "pgcrypto" unless extension_enabled?("pgcrypto")

    create_table :users do |t|
      t.string :email, null: false
      t.string :name
      t.string :password_digest, limit: 255
      t.string :role, null: false, default: "user"
      t.string :uuid, null: false
      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :uuid, unique: true

    create_table :active_storage_blobs do |t|
      t.string :key, null: false
      t.string :filename, null: false
      t.string :content_type
      t.text :metadata
      t.string :service_name, null: false
      t.bigint :byte_size, null: false
      t.string :checksum
      t.datetime :created_at, null: false
      t.index :key, unique: true
    end

    create_table :active_storage_attachments do |t|
      t.string :name, null: false
      t.string :record_type, null: false
      t.bigint :record_id, null: false
      t.references :blob, null: false, foreign_key: { to_table: :active_storage_blobs }
      t.datetime :created_at, null: false
      t.index [ :record_type, :record_id, :name, :blob_id ], name: :index_active_storage_attachments_uniqueness, unique: true
    end

    create_table :active_storage_variant_records do |t|
      t.belongs_to :blob, null: false, index: false, foreign_key: { to_table: :active_storage_blobs }
      t.string :variation_digest, null: false
      t.index [ :blob_id, :variation_digest ], name: :index_active_storage_variant_records_uniqueness, unique: true
    end

    create_table :teams do |t|
      t.string :name, null: false
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :updater, null: false, foreign_key: { to_table: :users }
      t.string :uuid, null: false
      t.timestamps
    end
    add_index :teams, :name, unique: true
    add_index :teams, :uuid, unique: true

    create_table :categories do |t|
      t.string :name, null: false
      t.string :color
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :updater, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :categories, :name, unique: true

    create_table :tags do |t|
      t.string :name, null: false
      t.string :color
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :updater, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :tags, :name, unique: true

    create_table :prompts do |t|
      t.string :title
      t.text :description, null: false
      t.text :content, null: false
      t.references :category, null: false, foreign_key: true
      t.integer :favorites_count, default: 0
      t.boolean :is_anonymous, default: false
      t.string :visibility
      t.bigint :pinned_comment_id
      t.integer :uses_count, default: 0
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :updater, null: false, foreign_key: { to_table: :users }
      t.string :uuid, null: false
      t.timestamps
    end
    add_index :prompts, :pinned_comment_id
    add_index :prompts, :uuid, unique: true

    create_table :comments do |t|
      t.text :content
      t.references :prompt, null: false, foreign_key: true
      t.integer :votes_score, default: 0
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.references :updater, null: false, foreign_key: { to_table: :users }
      t.datetime :deleted_at
      t.timestamps
    end
    add_index :comments, [ :prompt_id, :creator_id ], unique: true
    add_foreign_key :prompts, :comments, column: :pinned_comment_id

    create_table :comment_votes, primary_key: [ :user_id, :comment_id ] do |t|
      t.references :comment, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.integer :value, null: false
      t.datetime :created_at, null: false
    end
    add_index :comment_votes, [ :user_id, :comment_id ]

    create_table :favorites, primary_key: [ :user_id, :prompt_id ] do |t|
      t.references :prompt, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
    add_index :favorites, [ :user_id, :prompt_id ]

    create_table :prompt_tags, primary_key: [ :prompt_id, :tag_id ] do |t|
      t.references :prompt, null: false, foreign_key: true
      t.references :tag, null: false, foreign_key: true
    end
    add_index :prompt_tags, [ :prompt_id, :tag_id ]

    create_table :prompt_usages, id: false do |t|
      t.references :prompt, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.datetime :created_at, null: false
    end
    add_index :prompt_usages, [ :user_id, :prompt_id ]

    create_table :team_users, primary_key: [ :team_id, :user_id ] do |t|
      t.references :team, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true
      t.boolean :is_group_mod, default: false
      t.datetime :created_at, null: false
    end
    add_index :team_users, [ :team_id, :user_id ]

    create_table :prompt_teams do |t|
      t.references :prompt, null: false, foreign_key: true
      t.references :team, null: false, foreign_key: true
      t.references :creator, null: false, foreign_key: { to_table: :users }
      t.timestamps
    end
    add_index :prompt_teams, [ :prompt_id, :team_id ], unique: true

    create_table :help_blocks do |t|
      t.string :uuid, null: false
      t.text :body, null: false
      t.string :style_variant, null: false, default: "card"
      t.integer :column_start, null: false, default: 1
      t.integer :column_span, null: false, default: 1
      t.integer :row_start, null: false, default: 1
      t.integer :row_span, null: false, default: 1
      t.timestamps
    end
    add_index :help_blocks, :uuid, unique: true
    add_index :help_blocks, [ :row_start, :column_start ]

    create_table :help_guide_drafts do |t|
      t.string :key, null: false
      t.text :payload, null: false, default: '{"blocks":[]}'
      t.datetime :saved_at
      t.datetime :published_at
      t.timestamps
    end
    add_index :help_guide_drafts, :key, unique: true
  end
end
