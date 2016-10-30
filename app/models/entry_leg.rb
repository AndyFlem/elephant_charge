class EntryLeg < ApplicationRecord
  belongs_to :entry
  belongs_to :leg
  belongs_to :checkin1, foreign_key: 'checkin1_id', class_name: 'Checkin'
  belongs_to :checkin2, foreign_key: 'checkin2_id', class_name: 'Checkin'

  def position
    self.leg.entry_legs.order(:distance_m).each_with_index do |entleg,i|
      if entleg.entry_id==self.entry_id
        return i+1
      end
    end
  end
end