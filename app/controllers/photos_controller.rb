require 'zip'
class PhotosController < ApplicationController

  def update_all
    @charge = Charge.find(params[:id])
    phts=params[:charge][:photo]

    phts.each do |pht_no|
      pht=phts[pht_no]
      photo=Photo.find(pht_no)

      if pht[:delete]=="1"
        photo.destroy
      else
        if pht[:remove]=="1"
          photo.photoable=@charge
        end
        if !pht[:photoable].nil? and pht[:photoable]!=""
          entry=@charge.entries.find(pht[:photoable])
          photo.photoable=entry
        end
        photo.is_car=pht[:is_car]
        photo.save!
      end
    end
    if params[:car_no].nil?
      redirect_to charge_photos_path @charge
    else
      redirect_to charge_entry_path @charge,params[:car_no]
    end

  end

  def index
    @charge = Charge.find(params[:charge_id])
    @photos=@charge.photos
    @entries=@charge.entries.order(:name).collect{|p| [ p.car_no.to_s + ' - ' + p.name, p.car_no ] }
  end

  def destroy
    @charge = Charge.find(params[:charge_id])
    photo= Photo.find(params[:id])
    if photo.photoable.class==Entry
      entry=photo.photoable
      photo.photoable=@charge
      photo.save!
      redirect_to charge_entry_path(@charge,entry)
    else
      photo.destroy
      redirect_to charge_photos_path(@charge)
    end
  end

  def create
    @charge = Charge.find(params[:charge_id])

    uploaded = params[:photo][:photo]

    type=uploaded.original_filename.split('.').last

    if (type=='zip') then

      dir = File.join(::Rails.root,"public","events","temp")
      FileUtils.mkdir_p(dir)

      Zip::InputStream.open(uploaded.tempfile) do |zis|
        while entry = zis.get_next_entry
          filename = File.join(dir,entry.name)
          entry.extract(filename)
          p = File.new(filename)
          photo=@charge.photos.new()
          photo.photo=p
          photo.save!
          p.close
          FileUtils.remove_file(filename)
        end
      end
    else
      photo=@charge.photos.new()
      photo.photo=uploaded

      photo.save!
    end

    redirect_to charge_path(@charge)
  end

  def show
    @photo=Photo.find(params[:id])
    #@faces=@photo.faces
    #@face_bounds=@photo.faces_bounds

  end
end