class Team < ApplicationRecord
  has_many :entries
  has_many :charges, through: :entries

  has_attached_file :badge,
                    styles: { original: "600x600",medium: "200x200", thumb: "100x100"},
                    default_url: "/images/:style/missing.png"
  validates_attachment_content_type :badge, content_type: /\Aimage\/.*\z/

  validates :name, presence: true

  def finish_count
    self.entries.where("result_description='Complete'").count
  end

  def entries_complete
    self.entries.includes(:charge).references(:charge).where("charges.state_ref='RESULT'")
  end

  def entries_incomplete
    self.entries.includes(:charge).references(:charge).where("charges.state_ref!='RESULT'")
  end


  def long_name
    unless self.prefix.blank?
      self.prefix + ' ' + self.name
    else
      self.name
    end
  end

  def self.not_referenced_by(charge)
    query = <<-SQL
      SELECT * FROM teams
      WHERE id NOT IN (
        SELECT T.id
        FROM teams T INNER JOIN entries E ON T.id=E.team_id
        WHERE E.charge_id=#{charge.id})
    SQL

    Team.find_by_sql(query)
  end

  def raised_dollars
    sm=0
    self.entries.each do |e|
      unless e.raised_dollars.nil?
        sm+=e.raised_dollars
      end
    end
    sm
  end
  def raised_kwacha
    self.entries.all.sum(:raised_kwacha)
  end


end
