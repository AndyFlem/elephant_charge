class Entry < ApplicationRecord
  include FriendlyId
  friendly_id :car_no, use: :finders

  has_one :entry_geom

  belongs_to :charge, touch: true
  belongs_to :team
  belongs_to :car
  belongs_to :start_guard, foreign_key: 'start_guard_id', class_name: 'Guard'
  has_many :gps_raws
  has_many :gps_cleans
  has_many :gps_stops
  has_many :checkins
  has_many :entry_legs

  validates :car_no, numericality: { only_integer: true }
  validates :car_no, uniqueness: { scope: :charge_id}
  validates :car_id, uniqueness: { scope: :charge_id}
  validates :team_id, uniqueness: { scope: :charge_id}
  validates :charge, presence: true
  validates :team, presence: true
  validates :car, presence: true


  def types_description
    type=[]
    type << 'Ladies' if self.is_ladies
    type << 'New Entry' if self.is_newcomer
    type << 'International' if self.is_international
    type << 'Bikes' if self.is_bikes
    type << 'standard' if type.count==0
    type.join(', ')

  end

  def reset_raw!
    reset_clean!
    self.entry_geom.update_column(:raw_line,nil)
    self.entry_geom.update_column(:raw_line_kml,nil)
    self.entry_geom.update_column(:raw_line_json,nil)
    self.entry_geom.update_column(:raws_count,0)
    self.entry_geom.update_column(:raws_from,nil)
    self.entry_geom.update_column(:raws_to,nil)
    ActiveRecord::Base.connection.exec_query("DELETE FROM gps_raws WHERE entry_id=#{self.id}")
    self.update_column(:state_ref,nil)
    self.update_column(:state_messages,nil)
  end
  def reset_clean!
    self.entry_geom.update_column(:clean_line,nil)
    self.entry_geom.update_column(:clean_line_kml,nil)
    self.entry_geom.update_column(:clean_line_json,nil)
    self.entry_geom.update_column(:cleans_count,0)
    self.entry_geom.update_column(:stops_count,0)
    ActiveRecord::Base.connection.exec_query("DELETE FROM gps_cleans WHERE entry_id=#{self.id}")
    ActiveRecord::Base.connection.exec_query("DELETE FROM gps_stops WHERE entry_id=#{self.id}")
    self.update_column(:state_ref,"RAW")
  end
end
