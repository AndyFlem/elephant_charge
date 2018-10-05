class LegElevationJob< ActiveJob::Base
  queue_as :default


  def perform

    legs=EntryLeg.where("elevation_min=100000").order(:id)

    legs.each do |el|
      el_min=100000
      el_max=0

      pnts=el.gps_cleans
      pnts.each do |pnt|
        if pnt.elevation>el_max
          el_max=pnt.elevation
        end
        if pnt.elevation<el_min
          el_min=pnt.elevation
        end
      end
      el.elevation_min=el_min
      el.elevation_max=el_max
      el.save!
    end

  end




end