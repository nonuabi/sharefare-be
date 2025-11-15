# frozen_string_literal: true

class GroupInvite < ApplicationRecord
  belongs_to :group
  belongs_to :inviter, class_name: 'User', foreign_key: 'inviter_id'
  belongs_to :used_by, class_name: 'User', foreign_key: 'used_by_id', optional: true

  before_validation :generate_token, on: :create
  before_validation :set_expiration, on: :create

  validates :token, uniqueness: true, presence: true
  validate :not_expired, on: :update

  scope :active, -> { where(used: false).where('expires_at > ?', Time.current) }
  scope :expired, -> { where('expires_at <= ?', Time.current) }

  def expired?
    expires_at.present? && expires_at < Time.current
  end

  def can_be_used?
    !used && !expired?
  end

  def use!(user)
    return false unless can_be_used?

    update!(
      used: true,
      used_at: Time.current,
      used_by: user
    )
  end

  def invite_url
    # In production, this would be your app's deep link or web URL
    # For now, we'll use a simple format that can be handled by the app
    "chopbill://invite/#{token}"
  end

  private

  def generate_token
    return if token.present? # Don't regenerate if token already exists
    
    loop do
      self.token = SecureRandom.urlsafe_base64(32)
      break unless GroupInvite.exists?(token: token)
    end
  end

  def set_expiration
    # Invites expire in 30 days
    self.expires_at ||= 30.days.from_now if expires_at.blank?
  end

  def not_expired
    return unless used_changed? && used? && expired?

    errors.add(:base, 'Cannot use an expired invite')
  end
end

