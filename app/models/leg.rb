class Leg < ApplicationRecord
  has_many :entries
  has_many :legs
end