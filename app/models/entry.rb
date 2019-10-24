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
  has_many :photos, as: :photoable

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
  #dist_net;
  #dist_best


  def is_current?
    self.charge.has_result
  end

  def start_time
    unless self.checkins.nil? or self.checkins.count==0
      self.checkins.order(:checkin_number).first.checkin_timestamp
    end
  end
  def end_time
    unless self.checkins.nil? or self.checkins.count==0
      self.checkins.order(:checkin_number).last.checkin_timestamp
    end
  end

  def raised_dollars
    unless self.raised_kwacha.nil?
      self.raised_kwacha/self.charge.exchange_rate
    else
      0
    end
  end

  def types_description
    type=[]
    type << 'Ladies' if self.is_ladies
    type << 'New Entry' if self.is_newcomer
    type << 'International' if self.is_international
    type << 'Bikes' if self.is_bikes
    type << '' if type.count==0
    type.join(', ')
  end

  def update_distances!
    nongauntlet_dist_sum=0
    gauntlet_dist_sum=0
    best_dist_sum=0

    self.entry_legs.each do |entry_leg|
      best_dist_sum+=entry_leg.leg.distance_m
      if entry_leg.leg.is_gauntlet
        gauntlet_dist_sum+=entry_leg.distance_m
      else
        nongauntlet_dist_sum+=entry_leg.distance_m
      end
    end

    #dist_nongauntlet;
    self.dist_nongauntlet=nongauntlet_dist_sum

    #dist_gauntlet;
    self.dist_gauntlet=gauntlet_dist_sum

    #dist_withpentalty_nongauntlet;
    self.dist_withpentalty_nongauntlet=nongauntlet_dist_sum + self.dist_penalty_nongauntlet

    #dist_withpentalty_gauntlet;
    self.dist_withpentalty_gauntlet=gauntlet_dist_sum + self.dist_penalty_gauntlet

    #dist_multiplied_gauntlet;
    self.dist_multiplied_gauntlet=self.dist_withpentalty_gauntlet*self.charge.gauntlet_multiplier

    #dist_real;
    self.dist_real=nongauntlet_dist_sum+gauntlet_dist_sum;

    #dist_competition;
    self.dist_competition=self.dist_withpentalty_nongauntlet+self.dist_multiplied_gauntlet

    #dist_best
    self.dist_best=best_dist_sum

    #dist_net;
    
    if self.result_guards==self.charge.guards.count+1
      unless self.raised_kwacha.nil?
        self.dist_net=self.dist_competition-(self.raised_kwacha*self.charge.m_per_kwacha)
      end
    end

    update_tsetse_distances!

    self.save!



  end

  def update_tsetse_distances!
    unless self.charge.tsetse1_leg == nil or self.charge.tsetse1_leg == nil
      tsetse1=self.entry_legs.where(leg_id: self.charge.tsetse1_leg.id).first
      tsetse2=self.entry_legs.where(leg_id: self.charge.tsetse2_leg.id).first
      unless tsetse1.nil?
        self.dist_tsetse1=tsetse1.distance_m
      else
        self.dist_tsetse1=nil
      end
      unless tsetse2.nil?
        self.dist_tsetse2=tsetse2.distance_m
      else
        self.dist_tsetse2=nil
      end
      self.save!
    end
  end

  def result
    self.result_description
  end

  def update_result_state!
    #NOT_READY
    #READY
    #PROCESSED
    res=[]
    state='NOT_READY'
    if self.checkins.count>self.charge.guards.count+1
      res<<"Too many checkpoints #{self.checkins.count}"
    end
    if self.checkins.count==0
      res<<"No checkpoints defined"
    else
      if self.start_guard.nil?
        res<<"No starting checkpoint defined"
      else
        unless self.checkins.order(:checkin_number).first.guard.id==self.start_guard.id
          res<<"Unexpected first checkpoint #{self.checkins.order(:checkin_number).first.guard.name}"
        end
        checks={}
        self.checkins.order(:checkin_number).each do |checkin|

          if !checks[checkin.guard.id].nil? and (checkin.guard.id!=self.start_guard.id or checkin.checkin_number!=self.checkins.count)
            checkin.is_duplicate=true;
            checkin.save!
            checks[checkin.guard.id].is_duplicate=true;
            checks[checkin.guard.id].save!
            res<<"Duplicate checkpoint #{checkin.guard.name}"
          else
            if checkin.is_duplicate
              checkin.is_duplicate=false;
              checkin.save!
            end
          end
          checks[checkin.guard.id]=checkin
        end
      end

    end

    self.result_description=''
    if res==[]
      state='READY'
      if self.result_guards==self.checkins.count
        state='PROCESSED'
        
        if self.result_guards==self.charge.guards.count+1
          self.result_description='Complete'
        else
          self.result_description='DNF ' + self.result_guards.to_s
        end
      end
    end
    self.result_state_ref=state
    self.result_state_messages=res
    self.save!
  end

  def reset_positions_distances!
    self.update_column(:dist_nongauntlet,nil)
    self.update_column(:dist_gauntlet,nil)
    self.update_column(:dist_withpentalty_gauntlet,nil)
    self.update_column(:dist_withpentalty_nongauntlet,nil)
    self.update_column(:dist_multiplied_gauntlet,nil)
    self.update_column(:dist_real,nil)
    self.update_column(:dist_competition,nil)
    self.update_column(:dist_tsetse1,nil)
    self.update_column(:dist_tsetse2,nil)
    self.update_column(:dist_net,nil)
    self.update_column(:dist_best,nil)

    self.update_column(:position_distance,nil)
    self.update_column(:position_net_distance,nil)
    self.update_column(:position_gauntlet,nil)
    self.update_column(:position_tsetse1,nil)
    self.update_column(:position_tsetse2,nil)
    self.update_column(:position_ladies,nil)
    self.update_column(:position_international,nil)
    self.update_column(:position_newcomer,nil)
    self.update_column(:position_bikes,nil)
    self.update_column(:position_net_bikes,nil)

    self.save!
  end

  def reset_result!
    self.entry_legs.each do |eleg|
      leg=eleg.leg
      del_leg=false;
      if eleg.leg.entries.count==1
        del_leg=true
      end
      ActiveRecord::Base.connection.exec_query("UPDATE gps_cleans SET entry_leg_id=null WHERE entry_leg_id="+ eleg.id.to_s)

      eleg.destroy
      if del_leg
        leg.destroy
      end
    end

    self.update_column(:result_guards,0)
    self.update_column(:result_gauntlet_guards,0)

    self.reset_positions_distances!

    self.update_result_state!
    self.save!
  end

  def reset_checkins!
    reset_result!
    self.entry_legs.destroy_all
    self.checkins.destroy_all
    self.update_result_state!
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
