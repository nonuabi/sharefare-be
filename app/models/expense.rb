class Expense < ApplicationRecord
  belongs_to :group
  belongs_to :payer, class_name: 'User', foreign_key: 'payer_id'
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'

  has_many :split_expenses
end
