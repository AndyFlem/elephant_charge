class CheckinsController < ApplicationController

  def index
    @charge = Charge.find(params[:charge_id])
    @entry=@charge.entries.find(params[:entry_id])
    @checkins=@entry.checkins

    respond_to do |format|
      format.json {
        render json: @checkins.collect {|p| { lat: p.gps_clean.location.y, lon: p.gps_clean.location.x}}
      }
    end
  end


  def destroy

    checkin=Checkin.find(params[:id])
    entry=checkin.entry
    checkins=entry.checkins.where("checkin_number>#{checkin.checkin_number}")
    checkins.each do |check|
      check.checkin_number-=1
      check.save!
    end
    checkin.destroy
    entry.update_result_state!

    redirect_to charge_entry_path(entry.charge,entry)
  end
end