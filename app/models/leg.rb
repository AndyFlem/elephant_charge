class Leg < ApplicationRecord
  has_many :entry_legs
  belongs_to :guard1, foreign_key: 'guard1_id', class_name: 'Guard'
  belongs_to :guard2, foreign_key: 'guard2_id', class_name: 'Guard'
  belongs_to :charge
  has_many :entries, through: :entry_legs

end