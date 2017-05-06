class UpdateHogsName < ActiveRecord::Migration[5.0]
def up
    u=Team.find_by_ref('hogsandkisses')
    u.name='Lady Hogs'
    u.ref='ladyhogs'
    u.save!
    u.entries.each do |entry|
      entry.name='Lady Hogs'
      entry.save
    end
  end
end
