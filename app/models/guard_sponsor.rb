class GuardSponsor < ApplicationRecord
  has_many :guards
  has_many :charges, through: :guards
  validates :name, presence: true

  def self.not_referenced_by(charge)

    query = <<-SQL
      SELECT * FROM guard_sponsors
      WHERE id NOT IN (
        SELECT GS.id
        FROM guard_sponsors GS INNER JOIN guards G ON GS.id=G.guard_sponsor_id
        WHERE G.charge_id=#{charge.id})
    SQL

    GuardSponsor.find_by_sql(query)

  end

end
