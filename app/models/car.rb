class Car < ApplicationRecord
  has_many :entries
  has_many :charges, through: :entries
  has_many :teams, through: :entries

  validates :name, presence: true

  def self.not_referenced_by(charge)
    query = <<-SQL
      SELECT * FROM cars
      WHERE id NOT IN (
        SELECT C.id
        FROM cars C INNER JOIN entries E ON c.id=e.car_id
        WHERE E.charge_id=#{charge.id})
    SQL

    Car.find_by_sql(query)

  end
end
