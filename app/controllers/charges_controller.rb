include KmlReader
include GpsProcessor

class ChargesController < ApplicationController

  def recalc_distances
    @charge = Charge.find(params[:id])
    @entries = @charge.entries

    @entries.each do |e|
      e.update_distances!
    end
    @charge.update_positions!
    redirect_to charge_path @charge
  end

  def process_results
    @charge = Charge.find(params[:id])

    entries = @charge.entries
    entries.each do |e|
      e.reset_result!
      if e.state_ref=='CLEAN'
        GpsProcessor.guess_checkins(e)
        if e.result_state_ref=='READY'
          GpsProcessor.process_result(e)
        end
      end
    end
    redirect_to charge_path @charge
  end

  def clear_results
    @charge = Charge.find(params[:id])
    entries = @charge.entries
    entries.each do |e|
      e.reset_result!
    end
    redirect_to charge_path @charge
  end

  def kml
    @charge = Charge.find(params[:id])
    @entries = @charge.entries.order(:car_no)

    render 'kml/kml.kml',{type: :builder,formats: [:xml],layout: false}
  end

  def legstsetse
    @charge = Charge.find(params[:id])
    legs_params=params[:post][:leg]

    legs_params.each do |leg_id|
      leg_params=legs_params[leg_id]
      leg=@charge.legs.find(leg_id)
      leg.is_tsetse=leg_params[:is_tsetse]
      leg.save!
    end

    redirect_to charge_path @charge
  end

  def entriesbulk
    @charge = Charge.find(params[:id])
    @entries=@charge.entries.includes(:car,:team,:start_guard).order(car_no: :asc)
    @start_guards=@charge.guards.includes(:guard_sponsor).collect{|p| [ p.guard_sponsor.name, p.id ] }
    @teams=Team.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
    @cars=Car.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }

    @newentry=@charge.entries.new()
    render 'entriesbulk'
  end

  def entriesbulkpost
    @charge = Charge.find(params[:id])
    ents_params=params[:post][:entry]
    ents_params.each do |car_no|
      ent_params=ents_params[car_no]
      unless car_no=="-1"
        entry=@charge.entries.find(car_no)
        set_entry entry,ent_params
        entry.save!
      else
        if ent_params[:car_no]!=""
          entry=@charge.entries.new()
          set_entry entry,ent_params
          entry.car_no=ent_params[:car_no]
          entry.team_id=ent_params[:team_id]
          entry.car_id=ent_params[:car_id]
          entry.save!
          entry.reload
          entry.create_entry_geom!
        end
      end
    end
    redirect_to entriesbulk_charge_path(@charge)
  end

  def set_entry entry,ent_params
    entry.is_ladies=ent_params[:is_ladies]
    entry.is_international=ent_params[:is_international]
    entry.is_newcomer=ent_params[:is_newcomer]
    entry.is_bikes=ent_params[:is_bikes]
    entry.start_guard_id=ent_params[:start_guard_id]
    entry.raised_kwacha=ent_params[:raised_kwacha]
    entry.dist_penalty_gauntlet=ent_params[:dist_penalty_gauntlet]
    entry.dist_penalty_nongauntlet=ent_params[:dist_penalty_nongauntlet]
  end

  def stops
    @charge = Charge.find(params[:id])
    respond_to do |format|
      format.json {
        render json: @charge.gps_stops.collect {|p| { lat: p.location.y, lon: p.location.x}}
      }
      end
  end

  def uploadkml
    @charge = Charge.find(params[:id])

    uploaded_io = params[:kmlfile]
    points=KmlReader.readkml(uploaded_io)

    points.each do |point|
      existing=ChargeHelpPoint.where(name: point[0]).first
      unless existing.nil?
        existing.destroy
      end

      @helppoint=ChargeHelpPoint.create(name: point[0], charge_id: @charge.id)
      @helppoint.location = RGeo::Geographic.simple_mercator_factory.point(point[1], point[2])
      @helppoint.save
    end

    redirect_to charge_path params[:id]
  end

  def result
    @charge = Charge.find(params[:id])
    @shortest_dist=@charge.entries.order(position_distance: :asc)
    @gauntlet=@charge.entries.order(position_gauntlet: :asc)
    @net=@charge.entries.where('result_guards='+(@charge.guards_expected+1).to_s).order(position_net_distance: :asc)
    @raised=@charge.entries.order(raised_kwacha: :desc)
    @tsetselegs=@charge.legs.where(is_tsetse: true)

  end

  def index
    @charges = Charge.order(charge_date: :desc)
  end

  def show
    @charge = Charge.references(:entries).find(params[:id])

    @entries=@charge.entries.includes(:car,:team,:start_guard).order(car_no: :asc)
    #@entries=Entry.order(:car_no).includes(:car).includes(:team).where(charge_id: @charge.id)
    @guards=@charge.guards.order(is_gauntlet: :desc).includes(:guard_sponsor).order("guard_sponsors.name")
    @legs=@charge.legs.order(is_gauntlet: :desc,is_tsetse: :desc)

  end

  def new
    @charge=Charge.new()
  end

  def edit
    @charge = Charge.find(params[:id])
  end

  def create
    @charge = Charge.new(charge_params)
    @charge.ref=@charge.charge_date.strftime('%Y')

    if @charge.save
      redirect_to charges_path
    else
      render 'new'
    end

  end

  def update
    @charge = Charge.find(params[:id])

    if @charge.update(charge_params)
      redirect_to charge_path(@charge)
    else
      render 'edit'
    end
  end

  private
  def charge_params
    params.require(:charge).permit(:name, :charge_date,:location,:map_scale,:start_time,:end_time,:entries_expected,:gauntlet_multiplier, :exchange_rate, :m_per_kwacha, :guards_expected)
  end
end
