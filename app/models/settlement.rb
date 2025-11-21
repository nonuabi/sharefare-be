# frozen_string_literal: true

class Settlement < ApplicationRecord
  belongs_to :group
  belongs_to :payer, class_name: 'User', foreign_key: 'payer_id'
  belongs_to :payee, class_name: 'User', foreign_key: 'payee_id'
  belongs_to :settled_by, class_name: 'User', foreign_key: 'settled_by_id'

  validates :amount, presence: true, numericality: { greater_than: 0 }
  validates :payer_id, presence: true
  validates :payee_id, presence: true
  validate :payer_and_payee_different
  validate :users_are_group_members

  scope :for_group, ->(group) { where(group: group) }
  scope :between_users, ->(user1, user2) { where(payer: [user1, user2]).where(payee: [user1, user2]) }
  scope :recent, -> { order(created_at: :desc) }

  private

  def payer_and_payee_different
    return unless payer_id == payee_id

    errors.add(:base, 'Payer and payee must be different users')
  end

  def users_are_group_members
    return unless group

    unless group.users.include?(payer) && group.users.include?(payee)
      errors.add(:base, 'Both payer and payee must be members of the group')
    end
  end
end
