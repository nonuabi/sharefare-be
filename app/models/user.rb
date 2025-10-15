class User < ApplicationRecord
  include Devise::JWT::RevocationStrategies::JTIMatcher
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :jwt_authenticatable, jwt_revocation_strategy: self
  has_many :owned_groups, class_name: 'Group', foreign_key: 'owner_id'
  has_many :group_members
  has_many :groups, through: :group_members

  has_many :expenses
  has_many :split_expenses, through: :expenses
end
