class Guard < ApplicationRecord
  attr_accessor :location_latitude

  belongs_to :sponsor
  belongs_to :charge,touch: true
  has_many :starters, {:class_name=>'Entry', :foreign_key=>'start_guard_id'}
  has_many :checkins

  validates :radius_m, numericality: { only_integer: true, greater_than:0 }
  validates :charge, presence: true
  validates :sponsor, presence: true


  def name
    if self.sponsor.short_name.nil? or self.sponsor.short_name==""
      self.sponsor.name
    else
      self.sponsor.short_name
    end
  end
  def location_latitude
    if location.nil?
      nil
    else
      location.y
    end
  end
  def location_longitude
    if location.nil?
      nil
    else
        location.x
    end
  end
  def is_located?
    not self.location_latitude.nil? and not self.location_longitude.nil?
  end
end
