require 'zip'
require 'nokogiri'

module KmlReader

  def self.readkml(kml_io)

    type=kml_io.original_filename.split('.').last

    kml_doc=''
     if (type=='kmz') then
       Zip::File.open_buffer(kml_io.tempfile) do |zip_file|
         kml_doc=zip_file.first.get_input_stream.read
       end
     else
       kml_doc=File.open(kml_io.tempfile,'r').read
     end

    points=readxml(Nokogiri::XML(kml_doc))

  end

  private


  def readxml(kml_doc)
    points=[]
    kml_doc.remove_namespaces!
    pmarks=kml_doc.xpath('//Placemark')

    pmarks.each do |pmark|

      coors=pmark.at_xpath('.//coordinates').content.split(',')

      points<<[pmark.at_xpath('.//name').content,coors[0],coors[1]]
    end
    points
  end

end