class Grant < ApplicationRecord

  belongs_to :charge
  belongs_to :beneficiary

  validates :grant_kwacha, numericality: {only_integer: true,allow_nil: false }

  def grant_dollars
    self.grant_kwacha/self.charge.exchange_rate
  end

end