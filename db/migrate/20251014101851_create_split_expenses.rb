class CreateSplitExpenses < ActiveRecord::Migration[8.0]
  def change
    create_table :split_expenses do |t|
      t.float :paid_amount, default: 0.0
      t.float :due_amount, default: 0.0
      t.boolean :is_settled, default: false
      t.belongs_to :expense, foreign_key: true, null: false
      t.belongs_to :user, foreign_key: true, null: false

      t.timestamps
    end
  end
end
