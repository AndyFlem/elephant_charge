class GuardSponsorsController < ApplicationController
  def index
    @guard_sponsors = GuardSponsor.order(:name)
  end

  def show
    @guard_sponsor = GuardSponsor.find(params[:id])
  end

  def new
    @guard_sponsor=GuardSponsor.new()
  end

  def edit
    @guard_sponsor = GuardSponsor.find(params[:id])
  end

  def create
    @guard_sponsor = GuardSponsor.new(guard_sponsor_params)
    if @guard_sponsor.short_name==""
      @guard_sponsor.short_name=nil
    end

    if @guard_sponsor.save
      redirect_to guard_sponsors_path
    else
      render 'new'
    end
  end

  def destroy
    @guard_sponsor= GuardSponsor.find(params[:id])
    begin
      @guard_sponsor.destroy
      redirect_to guard_sponsors_path
    rescue
      redirect_to guard_sponsors_path,:flash => { :error => "Cant delete sponsor which is entered in a charge." }
    end
  end

  def update
    @guard_sponsor = GuardSponsor.find(params[:id])

    if @guard_sponsor.update(guard_sponsor_params)
      redirect_to guard_sponsors_path
    else
      render 'edit'
    end
  end

  private
  def guard_sponsor_params
    params.require(:guard_sponsor).permit(:name,:short_name)
  end
end
