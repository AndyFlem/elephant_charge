require 'json'
require 'net/http'

class GuardElevationsJob< ActiveJob::Base
  queue_as :default

  def perform
    h=Helpers.new

    points=Guard.where("elevation is null and location is not null").order(:id).limit(30)

    while points.count>0

      req="https://maps.googleapis.com/maps/api/elevation/json?locations="

      req+=points.map {|p| h.number_with_precision(p.location.y,precision:7) + ',' + h.number_with_precision(p.location.x,precision:7)}.join('|')

      req+='&key=' + 'AIzaSyANJSGBmelMOFrVk17rq8998UL2QyapfLk'
      puts(req)
      uri = URI(req)
      res = Net::HTTP.get(uri)
      puts(res)
      results = JSON.parse(res)["results"]

      results.each_with_index do |result,i|
        points[i].elevation=result["elevation"]
        #points[i].elevation_resolution=result["elevation_resolution"]
        points[i].save!
      end

      points=Guard.where("elevation is null  and location is not null").order(:id).limit(300)
    end


  end

end
class Helpers
  include ActionView::Helpers::NumberHelper
end