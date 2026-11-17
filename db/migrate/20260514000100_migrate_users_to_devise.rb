class MigrateUsersToDevise < ActiveRecord::Migration[8.1]
  def change
    rename_column :users, :password_digest, :encrypted_password
    change_column_default :users, :encrypted_password, from: nil, to: ""
    change_column_null :users, :encrypted_password, false, ""
  end
end
