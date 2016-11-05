class Team < ApplicationRecord
  has_many :entries
  has_many :charges, through: :entries
  validates :name, presence: true

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
      sm+=e.raised_dollars
    end
    sm
  end
  def raised_kwacha
    sm=0
    self.entries.each do |e|
      sm+=e.raised_kwacha
    end
    sm
  end

end
