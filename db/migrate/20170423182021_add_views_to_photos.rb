class AddViewsToPhotos < ActiveRecord::Migration[5.0]
  def change
    add_column :photos, :views, :integer
  end
end
