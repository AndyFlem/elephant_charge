class UpdateEmailSwamp < ActiveRecord::Migration[5.0]
  def up
    t=Team.find_by_ref('swampdonkey')
    t.email='brynn@rma.co.bw'
    t.save!
  end
end
