class CheckinsController < ApplicationController

  def destroy

    checkin=Checkin.find(params[:id])
    entry=checkin.entry
    checkins=entry.checkins.where("checkin_number>#{checkin.checkin_number}")
    checkins.each do |check|
      check.checkin_number-=1
      check.save!
    end
    checkin.destroy
    entry.check_duplicate_checkins

    redirect_to charge_entry_path(entry.charge,entry)
  end
end