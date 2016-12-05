class ImageRenameJob < ActiveJob::Base
  queue_as :default


  def perform
    Photo.all.each do |rec|
      new_file_name=rec.id.to_s + '.' + rec.photo.path.split('.').last.downcase
      unless new_file_name==rec.photo_file_name
        (rec.photo.styles.keys).each do |style|
          path = rec.photo.path(style)
          FileUtils.move(path, File.join(File.dirname(path), new_file_name))
        end

        rec.photo_file_name = new_file_name
        rec.save
      end
    end
  end
end