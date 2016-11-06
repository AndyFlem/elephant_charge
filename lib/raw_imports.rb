require 'nokogiri'
include GpsProcessor

module RawImports

  def import_historic(entry,teamname)
    entry.reset_raw!

    query = <<-SQL
          SELECT lat,lon,gps_timestamp FROM gps_historic
          WHERE charge=#{entry.charge.ref} and teamname='#{teamname}'
          ORDER BY gps_timestamp;
    SQL

    points=ActiveRecord::Base.connection.exec_query(query).rows.collect{|c| [c[0],c[1],c[2]]}

    add_raw(entry,points)
    GpsProcessor.process_raw(entry)
  end

  def self.import_gpx(entry,uploaded_io)
    entry.reset_raw!

    points=read_gpx(uploaded_io)
    add_raw(entry,points)
    GpsProcessor.process_raw(entry)
  end

  private

  def self.read_gpx(gpx_io)
    points=[]
    type=gpx_io.original_filename.split('.').last
    if type=='gpx'
      gpx_doc=File.open(gpx_io.tempfile,'r').read

      gpx=Nokogiri::XML(gpx_doc)
      gpx.remove_namespaces!

      trkpts=gpx.xpath('//trkpt[time]')

      trkpts.each do |pnt|

        points<<[pnt.attribute('lat').value,pnt.attribute('lon').value,pnt.at_xpath('./time').content]
      end
    end
    points
  end

  def self.add_raw(entry,points)


    points.sort! { |x,y| x[2] <=> y[2] }
    count=0
    last_time=entry.charge.start_datetime

    points.each do |point|
      point_time=Time.parse(point[2])
      if point_time>entry.charge.start_datetime-10.minutes and point_time<entry.charge.end_datetime + 40.minutes + (entry.late_finish_min.nil? ? 0 : entry.late_finish_min).minutes
        if point_time-last_time>1.seconds
          location=RGeo::Geographic.simple_mercator_factory.point(point[1], point[0])
          query = <<-SQL
          INSERT INTO gps_raws (entry_id,location,location_prj,gps_timestamp) VALUES (
          #{entry.id},
          ST_GeomFromText('POINT (#{point[1]} #{point[0]})',4326),
          ST_Transform(ST_GeomFromText('POINT (#{point[1]} #{point[0]})',4326),3857),
          '#{point[2]}'
          );
          SQL
          ActiveRecord::Base.connection.exec_query(query)
          count+=1
        end
        last_time=point_time
      end
    end
  end
end