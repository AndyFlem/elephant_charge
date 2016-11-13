class Grant < ApplicationRecord

  belongs_to :charge
  belongs_to :beneficiary

  validates :grant_kwacha, numericality: {only_integer: true,allow_nil: false }

end