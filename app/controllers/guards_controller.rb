class GuardsController < ApplicationController
  def index
    @charge = Charge.find(params[:charge_id])
    @guards = Guard.order(is_gauntlet: :desc).includes(:guard_sponsor,:charge).order("guard_sponsors.name").where(charge_id: @charge.id)

    respond_to do |format|
      format.html # index.html.erb
      format.json {

        render json: @guards.collect {|p| {
            :name =>p.guard_sponsor.short_name ? p.guard_sponsor.short_name : p.guard_sponsor.name,
            :lat=>p.location_latitude,
            :lon=>p.location_longitude,
            :is_gauntlet=>p.is_gauntlet,
            :radius=>p.radius_m
        } }
      }
    end
  end

  def show
    @charge=Charge.find(params[:charge_id])
    @guard=@charge.guards.find(params[:id])

    respond_to do |format|
      format.html # index.html.erb
      format.json {
        lines=ActiveRecord::Base.connection.exec_query("SELECT ec_rawlinesnearguard(#{@guard.id})").rows
        res=lines.collect {|p| {type: 'Feature',properties:{name:''}, geometry:JSON.parse(p[0])}}

        render json: res
      }
    end
  end

  def new
    @charge=Charge.find(params[:charge_id])
    @guard=Guard.new()
    @guard_sponsors=GuardSponsor.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
    @help_points=@charge.charge_help_points.collect {|p| [ p.name, p.id ] }
  end

  def create
    @charge = Charge.find(params[:charge_id])

    guard_params=params[:guard]
    guard_sponsor=GuardSponsor.find(guard_params[:guard_sponsor_id])

    location=get_location(guard_params)

    @guard=Guard.new(charge:@charge,location:location,guard_sponsor: guard_sponsor,radius_m: guard_params[:radius_m], is_gauntlet: guard_params[:is_gauntlet])

    if @guard.save
      redirect_to charge_path(@charge)
    else
      @guard_sponsors=GuardSponsor.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
      @guard_sponsors<<[@guard.guard_sponsor.name,@guard.guard_sponsor.id]
      @help_points=@charge.charge_help_points.collect {|p| [ p.name, p.id ] }
      render 'new'
    end
  end

  def edit
    @charge=Charge.find(params[:charge_id])
    @guard = Guard.find(params[:id])

    @guard_sponsors=GuardSponsor.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
    @guard_sponsors<<[@guard.guard_sponsor.name,@guard.guard_sponsor.id]
    @help_points=@charge.charge_help_points.collect {|p| [ p.name, p.id ] }
  end

  def update
    @charge = Charge.find(params[:charge_id])
    @guard = Guard.find(params[:id])

    guard_params=params[:guard]
    guard_sponsor=GuardSponsor.find(guard_params[:guard_sponsor_id])

    location=get_location(guard_params)

    if @guard.update(location:location,guard_sponsor: guard_sponsor,radius_m: guard_params[:radius_m], is_gauntlet: guard_params[:is_gauntlet])
      redirect_to edit_charge_guard_path(@charge,@guard)
    else
      @guard_sponsors=GuardSponsor.not_referenced_by(@charge).sort_by {|p| [p.name, p.id]}.collect {|p| [ p.name, p.id ] }
      @guard_sponsors<<[@guard.guard_sponsor.name,@guard.guard_sponsor.id]
      @help_points=@charge.charge_help_points.collect {|p| [ p.name, p.id ] }
      render 'edit'
    end
  end


  def destroy
    @guard = Guard.find(params[:id])
    @guard.destroy

    @charge = Charge.find(params[:charge_id])
    redirect_to charge_path(@charge)
  end

  private
  def guard_params
    params.require(:guard).permit(:is_gauntlet,:radius_m,:guard_sponsor_id)
  end

  def get_location(guard_params)
    if guard_params[:location_longitude] !='' and guard_params[:location_latitude] !=''
      RGeo::Geographic.simple_mercator_factory.point(guard_params[:location_longitude], guard_params[:location_latitude])
    else
      if params[:help_point]!=''
        help_point=ChargeHelpPoint.find(params[:help_point])
        help_point.location
      end
    end

  end

end
