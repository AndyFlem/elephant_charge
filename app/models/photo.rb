class Photo < ApplicationRecord

  belongs_to :photoable, polymorphic: true

  before_save :extract_dimensions,:facedetect


  has_attached_file :photo,
                    styles: { original: "600x600",medium: "200x200", thumb: "100x100" },
                    default_url: "/images/:style/missing.png"
  validates_attachment_content_type :photo, content_type: /\Aimage\/.*\z/

  scope :has_faces, -> { where("faces_count>0") }
  scope :no_faces, -> { where("faces_count=0") }

  def delete #dummy property
    false
  end
  def remove #dummy property
    false
  end
  def badge  #dummy property
    false
  end

  def faces_bounds
    if faces_count>0
    coords=[
        self.faces.map {|a| a[0]}.min,
        self.faces.map {|a| a[1]}.min,
        self.faces.map {|a| a[0]+a[2]}.max,
        self.faces.map {|a| a[1]+a[3]}.max]
    [coords[0],coords[1],coords[2]-coords[0],coords[3]-coords[1]]
    else
      [0,0,0,0]
      end
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
  def facedetect
    res=`python lib/assets/python/facedetect.py --search-threshold 9 #{self.photo.path} 2>&1`
    res=res.split("\n").map {|e| e.split(' ')}
    self.faces=res
    self.faces_count=res.count
  end

end