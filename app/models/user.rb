class User < ApplicationRecord
  has_paper_trail

  include Devise::JWT::RevocationStrategies::JTIMatcher
  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  devise :database_authenticatable, :registerable,
         :recoverable, :rememberable, :validatable, :jwt_authenticatable, jwt_revocation_strategy: self
  
  # Override Devise's email validation to make it optional when phone_number is present
  def email_required?
    phone_number.blank?
  end
  
  # Custom validations
  validates :name, presence: true
  validate :email_or_phone_required
  validate :email_format_if_present
  validates :phone_number, uniqueness: { allow_nil: true }, format: { 
    with: /\A\+?[1-9]\d{1,14}\z/, 
    message: "must be a valid phone number" 
  }, allow_nil: true
  
  has_many :owned_groups, class_name: 'Group', foreign_key: 'owner_id'
  has_many :group_members
  has_many :groups, through: :group_members
  has_many :group_invites, foreign_key: 'inviter_id', class_name: 'GroupInvite'

  has_many :expenses
  has_many :split_expenses, through: :expenses

  after_create :generate_avatar, if: -> { avatar_svg.blank? }

  # Override Devise's authentication key to support both email and phone
  def self.find_for_database_authentication(warden_conditions)
    conditions = warden_conditions.dup
    login = conditions.delete(:login) || conditions.delete(:email) || conditions.delete(:phone_number)
    
    if login
      # Try to find by email first, then by phone_number
      where(conditions).where(
        "(email = :value OR phone_number = :value)",
        value: login
      ).first
    else
      where(conditions).first
    end
  end

  # Get identifier for avatar generation (email or phone)
  def identifier_for_avatar
    email || phone_number || "user#{id}"
  end

  def avatar_url_or_generate
    # Generate avatar if SVG is missing
    if avatar_svg.blank?
      AvatarService.generate_avatar_url(self)
      reload
    end
    # Return URL endpoint (always /avatars/:id)
    "/avatars/#{id}"
  end

  # Display name for user
  def display_name
    name.presence || email.presence || phone_number.presence || "User #{id}"
  end

  private

  def email_or_phone_required
    if email.blank? && phone_number.blank?
      errors.add(:base, "Either email or phone number must be provided")
    end
  end

  def email_format_if_present
    if email.present? && !email.match?(/\A[^@\s]+@[^@\s]+\z/)
      errors.add(:email, "is invalid")
    end
  end

  def generate_avatar
    return if avatar_svg.present?
    
    AvatarService.generate_avatar_url(self)
  end
end
