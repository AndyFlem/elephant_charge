include RawImports
include GpsProcessor

class EntriesController < ApplicationController
  def geojson
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    #if we have clean then send that
    if @entry.state_ref=='CLEAN'
      render json: {type: 'Feature',properties:{name:@entry.team.name + ' - Clean'}, geometry:JSON.parse(@entry.entry_geom.clean_line_json)}
    else
      #otherwise raw
      if @entry.state_ref=='RAW'
        render json: {type: 'Feature',properties:{name:@entry.team.name + ' - Raw'}, geometry:JSON.parse(@entry.entry_geom.raw_line_json)}
      else
        render json: {}
      end
    end


    #otherwise CP order

    #otherwise nothing

  end

  def kml
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    render 'kml/entry.kml',{type: :builder,formats: [:xml],layout: false}
  end

  def process_result
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    GpsProcessor.process_result(@entry)

    redirect_to charge_entry_path @entry.charge,@entry
  end

  def guess_checkins
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    GpsProcessor.guess_checkins(@entry)

    redirect_to charge_entry_path @entry.charge,@entry
  end

  def process_clean
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    GpsProcessor.process_clean(@entry)

    redirect_to charge_entry_path @entry.charge,@entry
  end

  def import
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    unless params[:historic_team]==''
      RawImports.import_historic(@entry,params[:historic_team])
    end
    unless params[:gpxfile].nil?
      uploaded_io = params[:gpxfile]
      RawImports.import_gpx(@entry,uploaded_io)
    end
    redirect_to charge_entry_path @entry.charge,@entry
  end

  def index
    @charge = Charge.find(params[:charge_id])
    @entries = Entry.order(:car_no).includes(:car).includes(:team).where(charge_id: @charge.id)
  end

  def show
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    @checkins=@entry.checkins.includes(:guard).order(:checkin_number)
    @legs=@entry.entry_legs.includes(:leg)

    teams=ActiveRecord::Base.connection.exec_query("SELECT DISTINCT teamname FROM gps_historic WHERE charge=#{@charge.ref}")
    @historicteams=teams.rows.collect{|p| [p[0],p[0]]}

  end

  def new
    @charge=Charge.find(params[:charge_id])
    @entry=@charge.entries.new()
    @teams=Team.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
    @cars=Car.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
    @start_guards=@charge.guards.collect{|p| [ p.guard_sponsor.name, p.id ] }
  end

  def edit
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    @teams=Team.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
    @teams << [@entry.team.name, @entry.team.id]
    @cars=Car.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
    @cars << [@entry.car.name, @entry.car.id]
    @start_guards=@charge.guards.includes(:guard_sponsor).collect{|p| [ p.guard_sponsor.name, p.id ] }
  end

  def create
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.new(entry_params)

    if @entry.save
      @entry.create_entry_geom!
      redirect_to charge_path(@charge)
    else
      @teams=Team.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
      @cars=Car.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
      @start_guards=@charge.guards
      render 'new'
    end
  end

  def destroy
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    unless @entry.entry_geom.nil?
      @entry.entry_geom.destroy
    end

    @entry.destroy

    @charge = Charge.find(params[:charge_id])
    redirect_to charge_path(@charge)
  end


  def update
    @charge = Charge.find(params[:charge_id])
    @entry = @charge.entries.find(params[:id])

    if @entry.update(entry_params)
      redirect_to charge_entry_path(@charge,@entry)
    else
      @teams=Team.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
      @cars=Car.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }

      render 'edit'
    end
  end

  private
  def entry_params
    params.require(:entry).permit(:charge_id,:team_id,:car_id,:car_no,:is_ladies,:is_international,:is_newcomer,:is_bikes, :start_guard_id)
  end
end
