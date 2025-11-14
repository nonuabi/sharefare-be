class UserSerializer
  include JSONAPI::Serializer
  attributes :id, :email, :phone_number, :name
  
  attribute :avatar_url do |user|
    user.avatar_url_or_generate
  end
end
