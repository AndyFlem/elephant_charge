class Sponsor < ApplicationRecord
  has_many :guards
  has_many :charges, through: :guards
  validates :name, presence: true

  def self.not_referenced_by(charge)

    query = <<-SQL
      SELECT * FROM sponsors
      WHERE id NOT IN (
        SELECT GS.id
        FROM sponsors GS INNER JOIN guards G ON GS.id=G.sponsor_id
        WHERE G.charge_id=#{charge.id})
    SQL

    Sponsor.find_by_sql(query)

  end

end
