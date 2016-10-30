class LegsController < ApplicationController

  def index
    @charge=Charge.find(params[:charge_id])
    @legs=@charge.legs.order(is_gauntlet: :desc, is_tsetse: :desc)
  end

end