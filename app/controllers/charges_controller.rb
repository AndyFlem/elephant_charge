include KmlReader
include GpsProcessor
include XlsxGenerator

class ChargesController < ApplicationController

  def generate_xlsx
    @charge = Charge.find(params[:id])
    XlsxGenerator.charge_xl(@charge)
    redirect_to charge_path @charge
  end

  def generate_kml
    @charge = Charge.find(params[:id])

    @entries = @charge.entries.order(:car_no)
    kml=render_to_string 'kml/kml.kml',{type: :builder,formats: [:xml],layout: false}
    File.open('public/system/charges/kml/elephant_charge_' + @charge.ref + '.kml','w'){|f| f << kml}

    redirect_to charge_path @charge
  end

  def recalc_distances
    @charge = Charge.find(params[:id])
    @entries = @charge.entries

    @entries.each do |e|
      e.reset_positions_distances!
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
    tsetses=@charge.legs.where('legs.is_tsetse=true')
    @charge.tsetse1_leg=tsetses[0]
    @charge.tsetse2_leg=tsetses[1]
    @charge.save!

    @charge.entries.each do |e|
      e.update_tsetse_distances!
    end
    @charge.update_tsetse_positions!

    redirect_to charge_path @charge
  end

  def charge_sponsordestroy
    @charge = Charge.find(params[:id])
    charge_sponsor=@charge.charge_sponsors.find(params[:charge_sponsor_id])
    charge_sponsor.destroy
    redirect_to charge_sponsors_charge_path(@charge)
  end

  def charge_sponsors
    @charge = Charge.find(params[:id])
    @chargesponsors=@charge.charge_sponsors.includes(:sponsor).references(:sponsor).order("sponsors.name")
    @sponsors=Sponsor.all.order(:name).collect{|p| [p.name,p.id]}
    @newchargesponsor=@charge.charge_sponsors.new()
  end

  def charge_sponsorspost
    @charge = Charge.find(params[:id])
    charge_sponsors_params=params[:post][:charge_sponsor]
    charge_sponsors_params.each do |charge_sponsor_id|
      charge_sponsors_params.each do |charge_sponsor_id|
        charge_sponsor_params=charge_sponsors_params[charge_sponsor_id]
        unless charge_sponsor_id=="-1"
          charge_sponsor=@charge.charge_sponsors.find(charge_sponsor_id)
          charge_sponsor.sponsor_id=charge_sponsor_params[:sponsor_id]
          charge_sponsor.type_ref=charge_sponsor_params[:type_ref]
          charge_sponsor.sponsorship_type_ref=charge_sponsor_params[:sponsorship_type_ref]
          charge_sponsor.sponsorship_description=charge_sponsor_params[:sponsorship_description]
          charge_sponsor.save!
        else
          if charge_sponsor_params[:type_ref]!=""
            charge_sponsor=@charge.charge_sponsors.new()
            charge_sponsor.sponsor_id=charge_sponsor_params[:sponsor_id]
            charge_sponsor.type_ref=charge_sponsor_params[:type_ref]
            charge_sponsor.sponsorship_type_ref=charge_sponsor_params[:sponsorship_type_ref]
            charge_sponsor.sponsorship_description=charge_sponsor_params[:sponsorship_description]
            charge_sponsor.save!
          end
        end
      end
      redirect_to charge_sponsors_charge_path(@charge)
    end
  end

  def grantdestroy
    @charge = Charge.find(params[:id])
    grant=@charge.grants.find(params[:grant_id])
    grant.destroy
    redirect_to grants_charge_path(@charge)
  end

  def grants
    @charge = Charge.find(params[:id])
    @grants=@charge.grants.includes(:beneficiary)
    @beneficiaries=Beneficiary.all.order(:name).collect{|p| [ p.name, p.id ] }
    @newgrant=@charge.grants.new()
  end

  def scrut
    @charge = Charge.find(params[:id])
    @entries=@charge.entries.includes([{:car => :make},:team]).order(car_no: :asc)
  end

  def grantspost
    @charge = Charge.find(params[:id])
    grants_params=params[:post][:grant]
    grants_params.each do |grant_id|
      grant_params=grants_params[grant_id]
      unless grant_id=="-1"
        #update existing
        grant=@charge.grants.find(grant_id)
        grant.grant_kwacha=grant_params[:grant_kwacha]
        grant.description=grant_params[:description]
        grant.save!
      else
        if grant_params[:grant_kwacha]!=""
          # create new
          grant=@charge.grants.new()
          grant.beneficiary_id=grant_params[:beneficiary_id]
          grant.grant_kwacha=grant_params[:grant_kwacha]
          grant.description=grant_params[:description]
          grant.save!
        end
      end
    end
    redirect_to grants_charge_path(@charge)
  end

  def entriesbulk
    @charge = Charge.find(params[:id])
    @entries=@charge.entries.includes(:car,:team,:start_guard).order(car_no: :asc)
    @start_guards=@charge.guards.includes(:sponsor).collect{|p| [ p.sponsor.name, p.id ] }
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
          entry.name=entry.team.name
          entry.captain=entry.team.captain
          entry.save!
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

  def uploadmap
    @charge = Charge.find(params[:id])
    @charge.map=params[:mapfile]
    @charge.save!
    redirect_to charge_path params[:id]
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
    @shortest_dist=@charge.entries.where("is_bikes=false").order(position_distance: :asc)
    @shortest_dist_bikes=@charge.entries.where("is_bikes=true and result_state_ref='PROCESSED'").order(position_distance: :asc)
    @shortest_dist_ladies=@charge.entries.where("is_ladies=true and result_state_ref='PROCESSED'").order(position_ladies: :asc)
    @shortest_dist_new=@charge.entries.where("is_newcomer=true and result_state_ref='PROCESSED'").order(position_newcomer: :asc)
    @gauntlet=@charge.entries.where("result_state_ref='PROCESSED' and result_gauntlet_guards>0").order(position_gauntlet: :asc)
    @net=@charge.entries.where("is_bikes=false and result_state_ref='PROCESSED' and result_guards="+(@charge.guards_expected+1).to_s).order(position_net_distance: :asc)
    @net_bikes=@charge.entries.where("is_bikes=true and result_state_ref='PROCESSED' and result_guards="+(@charge.guards_expected+1).to_s).order(position_net_distance: :asc)
    @raised=@charge.entries.order(raised_kwacha: :desc)
    #@tsetselegs=[@charge.tsetse1_leg,@charge.tsetse2_leg]

    @tsetse1=@charge.entries.where("position_tsetse1 is not null and result_state_ref='PROCESSED'").order(position_tsetse1: :asc)
    @tsetse2=@charge.entries.where("position_tsetse2 is not null and result_state_ref='PROCESSED'").order(position_tsetse2: :asc)

    @gauntlet_dist=0
    glegs=@charge.legs.where('is_gauntlet=true')
    glegs.each do |l|
      @gauntlet_dist+=l.distance_m
    end

  end

  def index
    @charges = Charge.order(charge_date: :desc)
  end

  def show
    @charge = Charge.references(:entries).find(params[:id])

    @entries=@charge.entries.includes(:car,:team,:start_guard).order(car_no: :asc)
    #@entries=Entry.order(:car_no).includes(:car).includes(:team).where(charge_id: @charge.id)
    @guards=@charge.guards.order(is_gauntlet: :desc).includes(:sponsor).order("sponsors.name")
    @legs=@charge.legs.order(is_gauntlet: :desc,is_tsetse: :desc)
    @grants=@charge.grants.includes(:beneficiary).order("beneficiaries.name")
    @photo=@charge.photos.new()
    @sponsors=@charge.charge_sponsors.includes(:sponsor).references(:sponsor).order("sponsors.name")
  end

  def new
    @charge=Charge.new()
    @entries=@charge.entries.order(:name).collect{|p| [ p.name, p.id ] }
    @guards=@charge.guards.includes(:sponsor).order("sponsors.name").collect{|p| [ p.sponsor.name, p.id ] }
  end

  def edit
    @charge = Charge.find(params[:id])
    @entries=@charge.entries.order(:name).collect{|p| [ p.name, p.id ] }
    @guards=@charge.guards.includes(:sponsor).order("sponsors.name").collect{|p| [ p.sponsor.name, p.id ] }
  end

  def create
    @charge = Charge.new(charge_params)
    @charge.ref=@charge.charge_date.strftime('%Y')

    if @charge.save
      redirect_to charges_path
    else
      @entries=@charge.entries.order(:name).collect{|p| [ p.name, p.id ] }
      @guards=@charge.guards.includes(:sponsor).order("sponsors.name").collect{|p| [ p.sponsor.name, p.id ] }
      render 'new'
    end

  end

  def update
    @charge = Charge.find(params[:id])

    if params[:charge][:spirit_entry_id]!=""
      params[:charge][:spirit_name]=@charge.entries.find(params[:charge][:spirit_entry_id]).name
    end

    if @charge.update(charge_params)
      redirect_to charge_path(@charge)
    else
      render 'edit'
    end
  end

  private
  def charge_params
    params.require(:charge).permit(:name, :charge_date,:location,:map_scale,
                                   :start_time,:end_time,:gauntlet_multiplier,
                                   :exchange_rate, :m_per_kwacha,
                                   :spirit_description,:spirit_name,:spirit_entry_id,
                                   :shafted_entry_id,:shafted_description,:best_guard_id, :has_result)
  end
end
