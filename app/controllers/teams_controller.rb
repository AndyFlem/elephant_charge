class TeamsController < ApplicationController
  def index
    @teams = Team.order(:name)
  end

  def show
    @team = Team.find(params[:id])
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

  private
  def team_params
    params.require(:team).permit(:name,:captain)
  end
end
