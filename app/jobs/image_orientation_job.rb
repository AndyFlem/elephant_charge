class ImageOrientationJob < ActiveJob::Base
  queue_as :default

  def perform
    Photo.all.each do |p|
      geometry = Paperclip::Geometry.from_file(p.photo.path)
      p.aspect=geometry.aspect
      p.save!
    end
  end
end