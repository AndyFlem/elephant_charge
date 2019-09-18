require 'nokogiri'
require 'csv'

require 'tiny_tds'
include GpsProcessor

module RawImports

  def self.geotab_vehicles()
    client = TinyTds::Client.new username: 'sa', password: 'extramild20',
                                 host: 'localhost', port: 1433,
                                 database: 'GEOTAB1', azure:false
    results = client.execute("SELECT iID,sDescription FROM Vehicle order by sDescription")

    results.collect{|p| [p["sDescription"],p["iID"]]}
   #[]
  end

  def self.import_geotab(entry,iVehicleID)
    entry.reset_raw!
    client = TinyTds::Client.new username: 'sa', password: 'extramild20',
                                 host: 'localhost', port: 1433,
                                database: 'GEOTAB1', azure:false

    qry="SELECT iID,CONVERT(VARCHAR(33), dtDateTime, 127)+'Z' AS sDateTime,fLatitude,fLongitude FROM GPSData WHERE iVehicleID=" + iVehicleID.to_s + " ORDER BY dtDateTime"
    results = client.execute(qry)


    points=results.collect{|c| [c["fLatitude"],c["fLongitude"],Time.parse(c["sDateTime"])]}

    add_raw(entry,points)
    GpsProcessor.process_raw(entry)
  end


  def import_historic(entry,teamname)
    entry.reset_raw!

    query = <<-SQL
          SELECT lat,lon,gps_timestamp FROM gps_historic
          WHERE charge=#{entry.charge.ref} and teamname='#{teamname}'
          ORDER BY gps_timestamp;
    SQL

    points=ActiveRecord::Base.connection.exec_query(query).rows.collect{|c| [c[0],c[1],Time.parse(c[2])]}

    add_raw(entry,points)
    GpsProcessor.process_raw(entry)
  end

  def self.import_gpx(entry,uploaded_io)
    entry.reset_raw!

    points=read_gpx(uploaded_io)

    if points.count>0
      add_raw(entry,points)
      if entry.gps_raws.count>0
        GpsProcessor.process_raw(entry)
      end
    end
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
        points<<[pnt.attribute('lat').value,pnt.attribute('lon').value,Time.parse(pnt.at_xpath('./time').content)]
      end
    end

    if type=='csv'
      header=true
      lat=nil;lon=nil;date=nil;time=nil;
      CSV.foreach(gpx_io.tempfile) do |line|
        if header
          line.each_with_index  do |col,i|
             lat=i if col.downcase.include?('lat')
             lon=i if col.downcase.include?('lon')
             date=i if col.downcase.include?('date')
             time=i if col.downcase.include?('time')
          end
        else
          if line!=[]
            if line[date].include?('/')
              points<<[line[lat],line[lon],Time.zone.strptime(line[date]+' '+line[time],"%m/%d/%Y %r")]
            else
              points<<[line[lat],line[lon],Time.parse(line[date] + ' ' + line[time])+2.hours]
            end
          end
        end
        header=false
      end
    end

    points
  end

  def self.add_raw(entry,points)

    points.sort! { |x,y| x[2] <=> y[2] }
    count=0
    last_time=entry.charge.start_datetime

    points.each_with_index do |point,i|
      point_time=point[2]
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