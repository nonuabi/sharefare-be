class AddAvatarSvgToUsers < ActiveRecord::Migration[8.0]
  def change
    add_column :users, :avatar_svg, :text
  end
end
