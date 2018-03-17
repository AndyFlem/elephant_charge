xml.instruct! :xml, :version => "1.0", :encoding => "UTF-8"
xml.kml do
  xml.Document do
    xml.name(@charge.name)

    xml.Style(id: 'cab') do
      xml.IconStyle do
        xml.scale(0.7)
        xml.Icon do
          xml.href('http://maps.google.com/mapfiles/kml/shapes/cabs.png')
        end
      end
    end

    xml.Folder do
      xml.name('Checkpoints')
      xml.visibility(1)
      @charge.guards.each do |guard|
        xml.Placemark do
          xml.name guard.name
          xml.visibility(1)
          xml.Point do
            xml.coordinates(guard.location.x.to_s + ',' + guard.location.y.to_s)
          end
        end
      end
    end


    @entries.each do |entry|
      xml << render(:partial=> 'kml/entry.kml',:locals => {:entry=>entry})
    end

  end
end
