# frozen_string_literal: true

class AvatarsController < ApplicationController
  skip_before_action :authenticate_user!, only: [:show]
  
  def show
    user = User.find_by(id: params[:id])
    return head :not_found unless user
    
    # Generate avatar SVG if not exists in database
    if user.avatar_svg.blank?
      AvatarService.generate_avatar_url(user)
      user.reload
    end
    
    # Serve SVG from database
    if user.avatar_svg.present?
      render xml: user.avatar_svg, content_type: "image/svg+xml"
    else
      # Fallback: regenerate if still missing
      AvatarService.generate_avatar_url(user)
      user.reload
      render xml: user.avatar_svg, content_type: "image/svg+xml"
    end
  rescue StandardError => e
    Rails.logger.error { "Avatar error: #{e.message}" }
    Rails.logger.error { e.backtrace.join("\n") }
    head :not_found
  end
end

