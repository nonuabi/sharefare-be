class User < ApplicationRecord
  has_paper_trail

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

  after_create :generate_avatar, if: -> { avatar_svg.blank? }

  def avatar_url_or_generate
    # Generate avatar if SVG is missing
    if avatar_svg.blank?
      AvatarService.generate_avatar_url(self)
      reload
    end
    # Return URL endpoint (always /avatars/:id)
    "/avatars/#{id}"
  end

  private

  def generate_avatar
    return if avatar_svg.present?
    
    AvatarService.generate_avatar_url(self)
  end
end
