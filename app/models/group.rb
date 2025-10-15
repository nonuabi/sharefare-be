# frozen_string_literal: true

class Group < ApplicationRecord
  has_paper_trail

  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'
  has_many :group_members
  has_many :users, through: :group_members

  has_many :expenses
  has_many :split_expenses, through: :expenses
end
