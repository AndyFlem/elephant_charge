class UpdateEmailSwamp < ActiveRecord::Migration[5.0]
  def up
    t=Team.find_by_ref('swampdonkey')
    t.email='brynn.morgan@icloud.com'
    t.save!
  end
end
