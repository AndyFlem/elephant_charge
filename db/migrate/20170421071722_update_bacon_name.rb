class UpdateBaconName < ActiveRecord::Migration[5.0]
  def up
    u=Team.find_by_ref('bacon')
    u.name='Hogs and Kisses'
    u.ref='hogsandkisses'
    u.save!
    u.entries.each do |entry|
      entry.name='Hogs and Kisses'
      entry.save
    end
  end
end
