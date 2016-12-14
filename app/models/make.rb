class Make < ApplicationRecord
  has_many :cars
  has_many :entries, through: :cars
  has_many :charges, through: :entries
end