class AddRefToMakes < ActiveRecord::Migration[5.0]
  def change
    add_column :makes, :ref, :string
  end
end
