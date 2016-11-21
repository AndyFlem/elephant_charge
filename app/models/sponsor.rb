class Sponsor < ApplicationRecord
  has_many :guards
  has_many :charges, through: :guards
  has_many :charge_sponsors


  validates :name, presence: true

  has_attached_file :logo,
                    styles: { medium: "200x200", thumb: "100x100" },
                    default_url: "/assets/:style/ec_logo_grey.png"
  validates_attachment_content_type :logo, content_type: /\Aimage\/.*\z/

  def self.not_referenced_by(charge)

    query = <<-SQL
      SELECT * FROM sponsors
      WHERE id NOT IN (
        SELECT GS.id
        FROM sponsors GS INNER JOIN guards G ON GS.id=G.sponsor_id
        WHERE G.charge_id=#{charge.id})
    SQL

    Sponsor.find_by_sql(query)

  end

end
