class Charge < ApplicationRecord
  include FriendlyId
  friendly_id :ref, use: :finders

  has_many :guards
  has_many :guard_sponsors, through: :guards
  has_many :entries
  has_many :teams, through: :entries
  has_many :charge_help_points
  has_many :gps_stops, through: :entries
  has_many :legs

  validates :name, presence: true
  validates :charge_date, presence: true
  validates :gauntlet_multiplier, numericality: {only_integer: true}
  validates :entries_expected, numericality: {only_integer: true,allow_nil: true }
  validates :exchange_rate, numericality: {allow_nil: true }
  validates :m_per_kwacha, numericality: {allow_nil: true }
  validates :guards_expected, numericality: {only_integer: true,allow_nil: false }


  after_initialize :init
  after_commit :process_updates


  def raised_dollars
    sm=0
    self.entries.each do |e|
      sm+=e.raised_dollars
    end
    sm
  end
  def raised_kwacha
    sm=0
    self.entries.each do |e|
      unless e.raised_kwacha.nil?
        sm+=e.raised_kwacha
      end
    end
    sm
  end

  def start_datetime
    self.charge_date + self.start_time.seconds_since_midnight.seconds
  end
  def end_datetime
    self.charge_date + self.end_time.seconds_since_midnight.seconds
  end

  def state_description
    if self.state_ref=="NOT_SETUP"
      "Not setup"
    end
    if self.state_ref=="READY"
      "Ready to process result"
    end
    if self.state_ref=="RESULT"
      "Result ready"
    end
  end

  def update_positions!

    #position_distance
    entries=self.entries.order(result_guards: :desc, dist_competition: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_distance=i+1
      p.save!
    end

    #position_net_distance
    entries=self.entries.order(result_guards: :desc, dist_net: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_net_distance=i+1
      p.save!
    end

    #gauntlet
    entries=self.entries.order(result_gauntlet_guards: :desc, dist_withpentalty_gauntlet: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_gauntlet=i+1
      p.save!
    end

    #position_raised
    entries=self.entries.order(raised_kwacha: :desc)
    entries.each_with_index do |p,i|
      p.position_raised=i+1
      p.save!
    end


  end

  protected

  def init
    self.start_time||="07:00 AM"
    self.end_time||="03:00 PM"
    self.map_scale||=12
    self.guards_count||=0
    self.entries_count||=0
    self.entries_expected||=0
    self.guards_located_count||=0
    self.state_ref||='NOT_SETUP'
    self.gauntlet_multiplier||=0
    self.m_per_kwacha||=0.5
    self.guards_expected||=10
  end

  def process_updates
    update_counts!
    update_map_center!
    update_state!
  end


  def update_state!

    state_messages=[]
    state_ref="RESULT"

    gauntlet_count=self.guards.where(is_gauntlet: true).count
    if gauntlet_count!=3
      state_messages<<"Wrong number of gauntlet checkpoints (#{gauntlet_count} of 3)"
      state_ref="NOT_SETUP"
    end
    if self.guards_count!=self.guards_expected
      state_messages<<"Not all checkpoints defined (#{self.guards_count} of #{self.guards_expected})"
      state_ref="NOT_SETUP"
    end
    if self.guards_located_count!=self.guards_expected
      state_messages<<"Not all checkpoints located (#{self.guards_located_count} of #{self.guards_expected})"
      state_ref="NOT_SETUP"
    end
    if self.entries_count!=self.entries_expected
      state_messages<<"No of teams not equal to expected (#{self.entries_count} for #{self.entries_expected} )"
      state_ref="NOT_SETUP"
    end
    if self.start_time.nil?
      state_messages<<"Start time not defined"
      state_ref="NOT_SETUP"
    end
    if self.end_time.nil?
      state_messages<<"End time not defined"
      state_ref="NOT_SETUP"
    end
    with_start=0
    self.entries.each do |entry|
      with_start+=1 unless entry.start_guard.nil?
    end
    if self.entries_count!=with_start
      state_messages<<"Not all teams have starting CP (#{with_start} of #{self.entries_count} )"
      state_ref="NOT_SETUP"
    end

    if state_ref=="RESULT"
      self.entries.each do |entry|
        unless entry.result_state_ref=='PROCESSED'
          state_ref=="READY"
        end
      end
    end

    update_column(:state_ref,state_ref)
    update_column(:state_messages,state_messages)

  end

  def update_counts!
    located_count=0
    for guard in self.guards
      if guard.is_located?
        located_count+=1
      end
    end
    update_column(:entries_count,self.entries.count)
    update_column(:guards_count,self.guards.count)
    update_column(:guards_located_count,located_count)
  end

  def update_map_center!
    res=ActiveRecord::Base.connection.exec_query("SELECT ec_chargecentroidfromguards(#{self.id});")
    unless res.rows[0][0].nil?
      cent=RGeo::Geographic.simple_mercator_factory.parse_wkt(res.rows[0][0])
      update_column(:map_center,cent)
    end
  end

end
