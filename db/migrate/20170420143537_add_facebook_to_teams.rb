class AddFacebookToTeams < ActiveRecord::Migration[5.0]
  def change
    add_column :teams, :facebook, :string
  end
end
