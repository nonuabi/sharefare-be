class MakeEmailOptionalInUsers < ActiveRecord::Migration[8.0]
  def up
    # Remove the existing unique index on email
    remove_index :users, :email if index_exists?(:users, :email)
    # Make email nullable
    change_column_null :users, :email, true
    # Add back unique index that allows nulls
    add_index :users, :email, unique: true, where: "email IS NOT NULL"
  end

  def down
    remove_index :users, :email if index_exists?(:users, :email)
    change_column_null :users, :email, false
    add_index :users, :email, unique: true
  end
end
