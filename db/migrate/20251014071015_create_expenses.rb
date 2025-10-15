class CreateExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :expenses do |t|
      t.belongs_to :group, foreign_key: true, null: false
      t.float :paid_amount, scale: 2
      t.boolean :is_settled, default: false
      t.belongs_to :payer, foreign_key: { to_table: :users }, null: false
      t.belongs_to :creator, foreign_key: { to_table: :users }, null: false

      t.timestamps
    end
  end
end
