# frozen_string_literal: true

namespace :avatars do
  desc "Migrate existing avatar files to database"
  task migrate_to_db: :environment do
    puts "Migrating avatars from files to database..."
    
    User.find_each do |user|
      next if user.avatar_svg.present?
      
      # Generate new avatar SVG and store in database
      AvatarService.generate_avatar_url(user)
      puts "Generated avatar for user #{user.id} (#{user.email})"
    end
    
    puts "Migration complete!"
  end
  
  desc "Clean up old avatar files (after migration)"
  task cleanup_files: :environment do
    avatars_dir = Rails.root.join("public", "avatars")
    if Dir.exist?(avatars_dir)
      files = Dir.glob(File.join(avatars_dir, "*.svg"))
      puts "Found #{files.count} avatar files to remove"
      files.each { |f| File.delete(f) }
      puts "Cleaned up avatar files"
    else
      puts "No avatars directory found"
    end
  end
end

