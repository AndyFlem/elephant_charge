class Charge < ApplicationRecord
  include FriendlyId
  friendly_id :ref, use: :finders

  has_many :guards
  has_many :sponsors, through: :guards
  has_many :entries
  has_many :teams, through: :entries
  has_many :charge_help_points
  has_many :gps_stops, through: :entries
  has_many :legs
  has_many :photos, as: :photoable
  has_many :charge_sponsors

  belongs_to :best_guard, foreign_key: 'best_guard_id', class_name: 'Guard'
  belongs_to :shafted_entry, foreign_key: 'shafted_entry_id', class_name: 'Entry'
  belongs_to :tsetse1_leg, foreign_key: 'tsetse1_id', class_name: 'Leg'
  belongs_to :tsetse2_leg, foreign_key: 'tsetse2_id', class_name: 'Leg'

  has_many :grants
  has_many :beneficiaries, through: :grants

  has_attached_file :map,
                    styles: { medium: "300x300", thumb: "100x100" },
                    default_url: "/images/:style/missing.png"
  validates_attachment_content_type :map, content_type: /\Aimage\/.*\z/

  validates :name, presence: true
  validates :charge_date, presence: true
  validates :gauntlet_multiplier, numericality: {only_integer: true}
  validates :exchange_rate, numericality: {allow_nil: true }
  validates :m_per_kwacha, numericality: {allow_nil: true }


  after_initialize :init
  after_commit :process_updates

  def long_name
    self.name + (self.location=='' ? '' : ' - ' + self.location)
  end

  def entries_complete
    self.entries.where(result_description: 'Complete').count
  end
  def entries_complete_percent
    self.entries_complete.to_f/self.entries_count.to_f*100
  end

  def winning_entry
    self.entries.order(position_distance: :asc).first
  end

  def award_winner ref
    case ref
      when :net_distance
        self.entries.where('position_net_distance=1').first
      when :raised
        self.entries.where('position_raised=1').first
      when :distance
        self.entries.where('position_distance=1').first
      when :gauntlet
        self.entries.where('position_gauntlet=1').first
      when :tsetse1
        self.entries.where('position_tsetse1=1').first
      when :tsetse2
        self.entries.where('position_tsetse2=1').first
      when :ladies
        self.entries.where('position_ladies=1').first
      when :bikes
        self.entries.where('position_bikes=1').first
      when :new
        self.entries.where('position_newcomer=1').first
      when :international
        self.entries.where('position_international=1').first
      else
        nil
    end
  end

  def self.awards_list
    {
        :net_distance=>['Country Choice Trophy','Shortest Net Distance'],
        :raised=>['Sausage Tree Trophy','Highest Sponsorship Raised'],
        :distance=>['Castle Fleming Trophy','Shortest Overall Distance'],
        :gauntlet=>['Mark Terken Trophy','Shortest Gauntlet Distance'],
        :tsetse1=>['Sanctuary Trophy','Shortest Distance on Tsetse Line 1'],
        :tsetse2=>['Khal Amazi Trophy','Shortest Distance on Tsetse Line 2'],
        :ladies=>['Silky Cup','Shortest Distance by a Ladies Team'],
        :new=>['','Shortest Distance New Team'],
        :international=>['','Shortest Distance International Team'],
        :bikes=>['Dean Cup','Shortest Distance by a Bike Team'],
        :spirit=>['Rhino Charge Trophy','Spirit of the Charge']

    }
  end

  def self.awards ref
    self.awards_list[ref][0].html_safe
  end
  def self.awards_desc ref
    self.awards_list[ref][1].html_safe
  end


  def entry_photos_count
    #self.entries.photo.all.count
    sm=0
    self.entries.each do |e|
      sm+=e.photos.count
    end
    sm
  end

  def grant_kwacha
    self.grants.all.sum(:grant_kwacha)
  end
  def grant_dollars
    self.grant_kwacha>0 ? self.grant_kwacha/self.exchange_rate : 0
  end

  def raised_dollars
    self.raised_kwacha>0 ? self.raised_kwacha/self.exchange_rate : 0
  end
  def raised_kwacha
    self.entries.all.sum(:raised_kwacha)
  end

  def start_datetime
    self.charge_date + self.start_time.seconds_since_midnight.seconds
  end
  def end_datetime
    self.charge_date + self.end_time.seconds_since_midnight.seconds
  end

  def update_positions!

    #position_distance
    entries=self.entries.where(is_bikes: false).order(result_guards: :desc, dist_competition: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_distance=i+1
      p.save!
    end

    #position_bikes
    entries=self.entries.where(is_bikes: true).order(result_guards: :desc, dist_competition: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_bikes=i+1
      p.save!
    end

    #position_net_distance
    entries=self.entries.where(is_bikes: false).order(result_guards: :desc, dist_net: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_net_distance=i+1
      p.save!
    end

    #position_net_bikes
    entries=self.entries.where(is_bikes: true).order(result_guards: :desc, dist_net: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_net_bikes=i+1
      p.save!
    end

    #gauntlet
    entries=self.entries.where(is_bikes: false).order(result_gauntlet_guards: :desc, dist_withpentalty_gauntlet: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_gauntlet=i+1
      p.save!
    end

    #position_raised
    entries=self.entries.order(raised_kwacha: :desc,car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_raised=i+1
      p.save!
    end

    #position_ladies
    entries=self.entries.where(is_ladies: true).order(result_guards: :desc, dist_competition: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_ladies=i+1
      p.save!
    end

    #position_international
    entries=self.entries.where(is_international: true).order(result_guards: :desc, dist_competition: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_international=i+1
      p.save!
    end

    #position_newcomer
    entries=self.entries.where(is_newcomer: true, is_bikes: false).order(result_guards: :desc, dist_competition: :asc, car_no: :asc)
    entries.each_with_index do |p,i|
      p.position_newcomer=i+1
      p.save!
    end


    update_tsetse_positions!
  end

  def update_tsetse_positions!

      unless self.tsetse1_leg.nil?
        pos=1
        entrylegs1=self.tsetse1_leg.entry_legs.order(distance_m: :asc)#

        entrylegs1.each_with_index do |p,i|
          unless p.entry.is_bikes
            p.entry.position_tsetse1=pos
            p.entry.save!
            pos+=1
          end
        end
      end

      #tsetse2
      unless self.tsetse2_leg.nil?
        entrylegs2=self.tsetse2_leg.entry_legs.order(distance_m: :asc)
        entrylegs2.each_with_index do |p,i|
          p.entry.position_tsetse2=i+1
          p.entry.save!
        end
      end
  end

  protected

  def init
    self.start_time||="07:00 AM"
    self.end_time||="03:00 PM"
    self.map_scale||=12
    self.guards_count||=0
    self.entries_count||=0
    self.guards_located_count||=0
    self.gauntlet_multiplier||=0
    self.m_per_kwacha||=0.5
  end

  def process_updates
    update_counts!
    update_map_center!
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
