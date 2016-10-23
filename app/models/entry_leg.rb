class EntryLeg < ApplicationRecord
  belongs_to :entry
  belongs_to :leg
  belongs_to :checkin1, foreign_key: 'checkin1_id', class_name: 'Checkin'
  belongs_to :checkin2, foreign_key: 'checkin2_id', class_name: 'Checkin'
end