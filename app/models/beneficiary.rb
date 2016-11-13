class Beneficiary < ApplicationRecord
  has_many :grants
  has_many :charges, through: :grants

  has_attached_file :logo,
                    styles: { medium: "200x200", thumb: "100x100" },
                    default_url: "/images/:style/missing.png"
  validates_attachment_content_type :logo, content_type: /\Aimage\/.*\z/
end