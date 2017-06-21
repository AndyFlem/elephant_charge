class AddTeamtextToTeam < ActiveRecord::Migration[5.0]
  def change
    add_column :teams, :teamtext, :string
  end
end
