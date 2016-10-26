include KmlReader

class ChargesController < ApplicationController


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
      unless car_no=="-1"
        ent_params=ents_params[car_no]
        entry=@charge.entries.find(car_no)

        entry.is_ladies=ent_params[:is_ladies]
        entry.is_international=ent_params[:is_international]
        entry.is_newcomer=ent_params[:is_newcomer]
        entry.is_bikes=ent_params[:is_bikes]
        entry.start_guard_id=ent_params[:start_guard_id]
        entry.raised_kwacha=ent_params[:raised_kwacha]
        entry.gauntlet_penalty_m=ent_params[:gauntlet_penalty_m]
        entry.other_penalty_m=ent_params[:other_penalty_m]
        entry.save!
      end

    end


    redirect_to entriesbulk_charge_path(@charge)
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


  def index
    @charges = Charge.order(charge_date: :desc)
  end

  def show
    @charge = Charge.references(:entries).find(params[:id])
    @entries=@charge.entries.includes(:car,:team,:start_guard).order(result_guards: :desc, distance_competition_m: :asc, car_no: :asc)
    #@entries=Entry.order(:car_no).includes(:car).includes(:team).where(charge_id: @charge.id)
    @guards=@charge.guards.order(is_gauntlet: :desc).includes(:guard_sponsor).order("guard_sponsors.name")
  end

  def new
    @charge=Charge.new()
  end

  def edit
    @charge = Charge.find(params[:id])
  end

  def create
    @charge = Charge.new(charge_params)

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
    params.require(:charge).permit(:name, :charge_date,:location,:map_scale,:start_time,:end_time,:entries_expected,:gauntlet_multiplier, :exchange_rate)
  end
end
