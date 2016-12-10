class GpsClean < ApplicationRecord
  belongs_to :entry
  belongs_to :entry_leg
end