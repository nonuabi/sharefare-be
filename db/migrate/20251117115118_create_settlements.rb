class CreateSettlements < ActiveRecord::Migration[8.0]
  def change
    create_table :settlements do |t|
      t.references :group, null: false, foreign_key: true
      t.references :payer, null: false, foreign_key: { to_table: :users }
      t.references :payee, null: false, foreign_key: { to_table: :users }
      t.decimal :amount, precision: 10, scale: 2, null: false
      t.references :settled_by, null: false, foreign_key: { to_table: :users }
      t.text :notes

      t.timestamps
    end
    
    add_index :settlements, [:group_id, :payer_id, :payee_id]
  end
end
