class CreateGroupInvites < ActiveRecord::Migration[8.0]
  def change
    create_table :group_invites do |t|
      t.references :group, null: false, foreign_key: true
      t.references :inviter, null: false, foreign_key: { to_table: :users }
      t.string :token, null: false, index: { unique: true }
      t.datetime :expires_at
      t.boolean :used, default: false, null: false
      t.datetime :used_at
      t.references :used_by, null: true, foreign_key: { to_table: :users }

      t.timestamps
    end
  end
end
