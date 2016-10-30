class Entry < ApplicationRecord
  include FriendlyId
  friendly_id :car_no, use: :finders

  after_initialize :init

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
  validates :dist_penalty_gauntlet, numericality: { only_integer: true,allow_nil: true }
  validates :dist_penalty_nongauntlet, numericality: { only_integer: true,allow_nil: true }
  validates :raised_kwacha, numericality: { only_integer: true,allow_nil: true }

  #dist_penalty_gauntlet;
  #dist_penalty_nongauntlet;
  #dist_nongauntlet;
  #dist_gauntlet;
  #dist_withpentalty_gauntlet;
  #dist_withpentalty_nongauntlet;
  #dist_multiplied_gauntlet;
  #dist_real;
  #dist_competition;
  #dist_tsetse1;
  #dist_tsetse2;

  def types_description
    type=[]
    type << 'Ladies' if self.is_ladies
    type << 'New Entry' if self.is_newcomer
    type << 'International' if self.is_international
    type << 'Bikes' if self.is_bikes
    type << '' if type.count==0
    type.join(', ')
  end

  def check_duplicate_checkins
    checks={}
    self.checkins.each do |checkin|
      if !checks[checkin.guard.id].nil? and checkin.guard.id!=self.start_guard.id
        checkin.is_duplicate=true;
        checkin.save!
        checks[checkin.guard.id].is_duplicate=true;
        checks[checkin.guard.id].save!
      else
        if checkin.is_duplicate
          checkin.is_duplicate=false;
          checkin.save!
        end
      end
      checks[checkin.guard.id]=checkin
    end
  end

  def is_result_processed
    if self.dist_competition.nil?
      false
    else
      true
    end
  end

  def is_ready_for_result_processing
    res=[]
    if self.checkins.count>11
      res<<"Too many checkpoints #{self.checkins.count}"
    end

    unless self.start_guard.nil?
      if self.checkins.count>0
        unless self.checkins.first.guard.id==self.start_guard.id
          res<<"Unexpected first checkpoint #{self.checkins.first.guard.name}"
        end
      end
      checks={}
      self.checkins.each do |checkin|
        if !checks[checkin.guard.id].nil? and checkin.guard.id!=self.start_guard.id
          res<<"Checkpoint #{checkin.guard.name} listed twice"
        end
        checks[checkin.guard.id]=true
      end
      if res==[]
        true
      else
        res
      end
    else
      res<<"Starting checkpoint not defined"
    end
  end

  def reset_result!
    self.entry_legs.each do |eleg|
      leg=eleg.leg
      del_leg=false;
      if eleg.leg.entries.count==1
        del_leg=true
      end
      eleg.destroy
      if del_leg
        leg.destroy
      end
    end

    self.update_column(:dist_nongauntlet,nil)
    self.update_column(:dist_gauntlet,nil)
    self.update_column(:dist_withpentalty_gauntlet,nil)
    self.update_column(:dist_withpentalty_nongauntlet,nil)
    self.update_column(:dist_multiplied_gauntlet,nil)
    self.update_column(:dist_real,nil)
    self.update_column(:dist_competition,nil)
    self.update_column(:dist_tsetse1,nil)
    self.update_column(:dist_tsetse2,nil)
  end

  def reset_checkins!
    reset_result!
    self.entry_legs.destroy_all
    self.checkins.destroy_all
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
    reset_checkins!
    self.entry_geom.update_column(:clean_line,nil)
    self.entry_geom.update_column(:clean_line_kml,nil)
    self.entry_geom.update_column(:clean_line_json,nil)
    self.entry_geom.update_column(:cleans_count,0)
    self.entry_geom.update_column(:stops_count,0)
    ActiveRecord::Base.connection.exec_query("DELETE FROM gps_cleans WHERE entry_id=#{self.id}")
    ActiveRecord::Base.connection.exec_query("DELETE FROM gps_stops WHERE entry_id=#{self.id}")
    self.update_column(:state_ref,"RAW")
  end

  protected
  def init
    self.dist_penalty_gauntlet||=0
    self.dist_penalty_nongauntlet||=0
  end
end
