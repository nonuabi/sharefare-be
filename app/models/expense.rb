# frozen_string_literal: true

# Expense
# Definitions: expense.rb
# Schema
#
# Columns
# id: integer (PK)
# group_id: integer (FK) - not null
# paid_amount: float
# is_settled: boolean - default: false
# payer_id: integer (FK) - not null
# creator_id: integer (FK) - not null
# description: string - not null, default: ''
# created_at: datetime - not null
# updated_at: datetime - not null
#
# Indexes
# index_expenses_on_creator_id (creator_id)
# index_expenses_on_group_id (group_id)
# index_expenses_on_payer_id (payer_id)
class Expense < ApplicationRecord
  has_paper_trail

  belongs_to :group
  belongs_to :payer, class_name: 'User', foreign_key: 'payer_id'
  belongs_to :creator, class_name: 'User', foreign_key: 'creator_id'

  has_many :split_expenses
end
