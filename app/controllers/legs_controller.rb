class LegsController < ApplicationController

  def index
    @charge=Charge.find(params[:charge_id])
    @legs=@charge.legs.order(is_gauntlet: :desc, is_tsetse: :desc)
  end

  def show
    @charge=Charge.find(params[:charge_id])
    @leg=Leg.find(params[:id])

    respond_to do |format|
      format.html # index.html.erb
      format.json {


        lines=ActiveRecord::Base.connection.exec_query("SELECT * FROM ec_linesforleg(#{@leg.id})").rows
        res=lines.collect {|p| {type: 'Feature',properties:{name:p[1]}, geometry:JSON.parse(p[0])}}

        render json: res
      }
    end
  end
end