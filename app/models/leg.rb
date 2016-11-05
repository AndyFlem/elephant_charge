class Leg < ApplicationRecord
  has_many :entry_legs
  belongs_to :guard1, foreign_key: 'guard1_id', class_name: 'Guard'
  belongs_to :guard2, foreign_key: 'guard2_id', class_name: 'Guard'
  belongs_to :charge
  has_many :entries, through: :entry_legs


  def location_x
    (self.guard1.location.x+self.guard2.location.x)/2
  end
  def location_y
    (self.guard1.location.y+self.guard2.location.y)/2
  end
end