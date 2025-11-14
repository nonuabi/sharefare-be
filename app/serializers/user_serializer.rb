class UserSerializer
  include JSONAPI::Serializer
  attributes :id, :email, :name
  
  attribute :avatar_url do |user|
    user.avatar_url_or_generate
  end
end
