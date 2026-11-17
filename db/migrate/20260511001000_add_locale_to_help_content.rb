class AddLocaleToHelpContent < ActiveRecord::Migration[8.1]
  def change
    add_column :help_blocks, :locale, :string, null: false, default: "pt-BR"
    add_index :help_blocks, [ :locale, :row_start, :column_start ]

    add_column :help_guide_drafts, :locale, :string, null: false, default: "pt-BR"
    remove_index :help_guide_drafts, column: :key, if_exists: true
    add_index :help_guide_drafts, [ :key, :locale ], unique: true
  end
end