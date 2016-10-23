include KmlReader

class ChargesController < ApplicationController

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
    @entries=@charge.entries.includes(:car,:team,:start_guard).order(:car_no)
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
    params.require(:charge).permit(:name, :charge_date,:location,:map_scale,:start_time,:end_time,:entries_expected)
  end
end
