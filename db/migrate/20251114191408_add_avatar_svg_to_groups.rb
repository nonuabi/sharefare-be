class AddAvatarSvgToGroups < ActiveRecord::Migration[8.0]
  def change
    add_column :groups, :avatar_svg, :text
  end
end
