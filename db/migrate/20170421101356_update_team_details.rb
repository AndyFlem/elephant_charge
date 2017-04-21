class UpdateTeamDetails < ActiveRecord::Migration[5.0]
  def up
    u=Team.find_by_ref('cfao')
    u.captain='Mark Vannierkerk'
    u.save!
    u.entries.each do |entry|
      entry.captain='Mark Vannierkerk'
      entry.save
    end
  end
end
