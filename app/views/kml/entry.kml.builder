xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.kml do
  xml.Document do
    xml.name(@entry.charge.name)

    #xml.Style(id: 'stop') do
    #  xml.IconStyle do
    #    xml.scale(0.7)
    #    xml.Icon do
    #      xml.href('http://maps.google.com/mapfiles/kml/shapes/forbidden.png')
    #    end
    #  end
    #end
    xml.Style(id: 'styleraw_' + @entry.car_no.to_s) do
      xml.LineStyle do
        xml.color('ff2fc978')
        xml.width(2)
      end
    end
    xml.Folder do
      xml.name(@entry.car_no.to_s + ' - ' + @entry.team.name)
      xml.open(0)
      xml.Placemark do
        xml.name(@entry.team.name + ' Raw Track')
        xml.styleUrl('#styleraw_' + @entry.car_no.to_s)
        xml.description()
        xml.visibility(1)
        xml.LineString do
          xml.tesselate(1)
          xml.extrude(1)
          unless @entry.entry_geom.nil?
            xml.coordinates(@entry.entry_geom.raw_line_kml)
          end
        end
      end
      xml.Placemark do
        xml.name(@entry.team.name + ' Clean Track')
        xml.styleUrl('#styleclean_' + @entry.car_no.to_s)
        xml.description()
        xml.visibility(1)
        xml.LineString do
          xml.tesselate(1)
          xml.extrude(1)
          unless @entry.entry_geom.nil?
            xml.coordinates(@entry.entry_geom.clean_line_kml)
          end
        end
      end

      xml.Folder do
        xml.name(@entry.team.name + ' Stops')
        xml.open(0)
        @entry.gps_stops.each do |stop|
          xml.Placemark do
            xml.name Time.at(stop.end_timestamp-stop.start_timestamp).utc.strftime("%H:%M:%S") + ' to ' + stop.end_timestamp.strftime("%H:%M:%S")
            xml.Point do
              xml.coordinates(stop.location.x.to_s + ',' + stop.location.y.to_s)
            end
          end
        end
      end
    end
  end
end