class Beneficiary < ApplicationRecord
  has_many :grants
  has_many :charges, through: :grants

  has_attached_file :logo,
                    styles: { medium: "200x200", thumb: "100x100" },
                    default_url: "/assets/:style/ec_logo_grey.png"
  validates_attachment_content_type :logo, content_type: /\Aimage\/.*\z/

  def grant_dollars
    grnts=0
    self.grants.each do |g|
      grnts+=g.grant_dollars
    end
    grnts
  end
end