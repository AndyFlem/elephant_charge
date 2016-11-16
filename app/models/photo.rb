class Photo < ApplicationRecord

  belongs_to :photoable, polymorphic: true

  before_save :extract_dimensions


  has_attached_file :photo,
                    styles: { original: "600x600",medium: "200x200", thumb: "100x100" },
                    default_url: "/images/:style/missing.png"
  validates_attachment_content_type :photo, content_type: /\Aimage\/.*\z/


  def delete #dummy property
    false
  end
  def remove #dummy property
    false
  end

  private

# Retrieves dimensions for image assets
# @note Do this after resize operations to account for auto-orientation.
  def extract_dimensions

    tempfile = photo.queued_for_write[:original]
    unless tempfile.nil?
      geometry = Paperclip::Geometry.from_file(tempfile)
      self.aspect=geometry.aspect
    end
  end
end