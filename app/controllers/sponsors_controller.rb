class SponsorsController < ApplicationController
  def index
    @sponsors = Sponsor.order(:name)
  end

  def show
    @sponsor = Sponsor.find(params[:id])
  end

  def new
    @sponsor=Sponsor.new()
  end

  def edit
    @sponsor = Sponsor.find(params[:id])
  end

  def create
    @sponsor = Sponsor.new(sponsor_params)
    if @sponsor.short_name==""
      @sponsor.short_name=nil
    end

    if @sponsor.save
      redirect_to sponsors_path
    else
      render 'new'
    end
  end


  def uploadlogo
    sponsor= Sponsor.find(params[:id])
    sponsor.logo=params[:logo]
    sponsor.save!
    redirect_to sponsors_path
  end

  def destroy
    @sponsor= Sponsor.find(params[:id])
    begin
      @sponsor.destroy
      redirect_to sponsors_path
    rescue
      redirect_to sponsors_path,:flash => { :error => "Cant delete sponsor which is entered in a charge." }
    end
  end

  def update
    @sponsor = Sponsor.find(params[:id])

    if @sponsor.update(sponsor_params)
      redirect_to sponsors_path
    else
      render 'edit'
    end
  end

  private
  def sponsor_params
    params.require(:sponsor).permit(:name,:short_name)
  end
end
