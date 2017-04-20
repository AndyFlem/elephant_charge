class UpdateTeamsFacebook < ActiveRecord::Migration[5.0]
  def up
    u=Team.find_by_ref('mudhogs')
    u.facebook='http://web.facebook.com/CLZ-Mudhogs-714377608708300'
    u.save!
    u=Team.find_by_ref('hotclutch')
    u.facebook='http://web.facebook.com/teamhotclutch'
    u.save!
  end
end
