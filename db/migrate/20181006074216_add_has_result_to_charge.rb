class AddHasResultToCharge < ActiveRecord::Migration[5.0]
  def up
    add_column :charges, :has_result, :boolean

    Charge.all.each do |charge|
      if charge.ref=='2019' or charge.ref=='2018'
        charge.has_result=false
      else
        charge.has_result=true
      end
      charge.save
    end
  end
end
