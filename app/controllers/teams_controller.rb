class TeamsController < ApplicationController
  def index
    @teams = Team.order(:name)
  end

  def photos
    @team = Team.find(params[:id])
  end
  def setbadge
    @team = Team.find(params[:id])

    phts=params[:team][:photo]

    phts.each do |pht_no|
      pht=phts[pht_no]
      photo=Photo.find(pht_no)

      if pht[:badge]=="1"
        @team.badge=photo.photo
        @team.save!
      end
    end


    redirect_to edit_team_path(@team)
  end

  def show
    @team = Team.find(params[:id])
    @entries=@team.entries.includes(:charge).order('charges.charge_date').references(:charges)

  end

  def new
    @team=Team.new()
  end

  def edit
    @team = Team.find(params[:id])
  end

  def create
    @team = Team.new(team_params)

    if @team.save
      redirect_to teams_path
    else
      render 'new'
    end

  end

  def destroy
    @team= Team.find(params[:id])
    begin
      @team.destroy
      redirect_to teams_path
    rescue
      redirect_to teams_path,:flash => { :error => "Cant delete team which is entered in a charge." }
    end
  end

  def update
    @team = Team.find(params[:id])

    if @team.update(team_params)
      redirect_to teams_path
    else
      render 'edit'
    end
  end

  def uploadbadge
    team= Team.find(params[:id])
    team.badge=params[:badge]
    team.save!
    redirect_to edit_team_path(team)
  end

  private
  def team_params
    params.require(:team).permit(:name,:captain,:ref,:badge,:paypal_button,:facebook)
  end
end
