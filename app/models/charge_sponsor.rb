class ChargeSponsor < ApplicationRecord
  belongs_to :charge
  belongs_to :sponsor

  def type_desc
    case self.type_ref
      when 'NAME'
        'Naming sponsor'
      when 'MAJOR'
        'Major sponsor'
      when 'STANDARD'
        'Standard sponsor'
    end
  end

  def sponsorship_type_desc
    case self.sponsorship_type_ref
      when 'CASH'
        'Financial donation'
      when 'KIND'
        'Equipment & services'
      when 'BOTH'
        'Financial donation and equipment & services'
    end
  end

  def self.type_refs
    [['Naming sponsor','NAME'],['Major sponsor','MAJOR'],['Standard sponsor','STANDARD']]
  end
  def self.sponsorship_type_refs
    [['Financial donation','CASH'],['Equipment & services','KIND'],['Financial donation and equipment & services','BOTH']]
  end

end