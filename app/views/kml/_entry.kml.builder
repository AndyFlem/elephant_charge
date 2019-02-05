
    xml.Folder do
      xml.Style(id: 'styleraw_' + entry.car_no.to_s) do
        xml.LineStyle do
          xml.color('ff' + random_color)
          xml.width(1)
        end
      end
      xml.Style(id: 'styleclean_' + entry.car_no.to_s) do
        xml.LineStyle do
          xml.color('ff' + random_color)
          xml.width(2)
        end
      end

      xml.name(entry.car_no.to_s + ' - ' + entry.team.name)
      xml.open(0)
  #    xml.Placemark do
   #     xml.name(entry.team.name + ' Raw Track')
    #    xml.visibility(0)
     #   xml.styleUrl('#styleraw_' + entry.car_no.to_s)
  #      xml.LineString do
   #       xml.tesselate(1)
    #      xml.extrude(1)
     #     unless entry.entry_geom.nil?
      #      xml.coordinates(entry.entry_geom.raw_line_kml)
    #      end
     #   end
      #end
      xml.Placemark do
        xml.name(entry.team.name + ' Clean Track')
        xml.visibility(1)
        xml.styleUrl('#styleclean_' + entry.car_no.to_s)
        xml.LineString do
          xml.tesselate(1)
          xml.extrude(1)
          unless entry.entry_geom.nil?
            xml.coordinates(entry.entry_geom.clean_line_kml)
          end
        end
      end

 #     xml.Folder do
        #xml.name(entry.team.name + ' Stops')
  #      xml.visibility(0)
   #     entry.gps_stops.each do |stop|
    #      xml.Placemark do
     #       xml.name Time.at(stop.end_timestamp-stop.start_timestamp).utc.strftime("%H:%M:%S") + ' to ' + stop.end_timestamp.strftime("%H:%M:%S")
      #      xml.visibility(0)
       #     xml.Point do
 #             xml.coordinates(stop.location.x.to_s + ',' + stop.location.y.to_s)
  #          end
   #       end
   #     end
    #  end


      xml.Folder do
        xml.name(entry.team.name + ' Animation')
        xml.visibility(0)
        xml.open(0)

        entry.gps_cleans.each do |clean|
          xml.Placemark do
            xml.styleUrl('#cab')
            xml.Point do
              xml.extrude(1)
              xml.coordinates(clean.location.x.to_s + ',' + clean.location.y.to_s + ',0')
            end
            xml.TimeSpan do
              xml.begin(clean.gps_timestamp.strftime('%FT%T'))
              xml.end((clean.gps_timestamp+90.seconds).strftime('%FT%T'))
            end
          end
        end
      end


    end
