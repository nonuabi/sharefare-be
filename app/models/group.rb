# frozen_string_literal: true

class Group < ApplicationRecord
  belongs_to :owner, class_name: 'User', foreign_key: 'owner_id'
  has_many :group_members
  has_many :users, through: :group_members
end
