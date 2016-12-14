class Car < ApplicationRecord
  has_many :entries
  has_many :charges, through: :entries
  has_many :teams, through: :entries
  belongs_to :make

  validates :name, presence: true

  def description
    des=''
    if !self.colour.blank?
      des+=self.colour.capitalize + ' '
    end
    if !self.year.blank?
      des+=self.year.to_s + ' '
    end
    if !self.make.blank?
      des+=self.make.name.capitalize + ' '
    end
    if !self.car_model.blank?
      des+=self.car_model + ' '
    end
    des

  end

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
