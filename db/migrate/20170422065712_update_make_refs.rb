class UpdateMakeRefs < ActiveRecord::Migration[5.0]
  def up
    t=Make.find_by_id(1)
    t.ref='isuzu'
    t.save!

    t=Make.find_by_id(2)
    t.ref='diahatsu'
    t.save!

    t=Make.find_by_id(3)
    t.ref='jeep'
    t.save!

    t=Make.find_by_id(4)
    t.ref='mercedes'
    t.save!

    t=Make.find_by_id(5)
    t.ref='bikes'
    t.save!

    t=Make.find_by_id(6)
    t.ref='rangerover'
    t.save!

    t=Make.find_by_id(7)
    t.ref='landrover'
    t.save!

    t=Make.find_by_id(8)
    t.ref='toyota'
    t.save!

    t=Make.find_by_id(9)
    t.ref='nissan'
    t.save!

    t=Make.find_by_id(10)
    t.ref='honda'
    t.save!

    t=Make.find_by_id(11)
    t.ref='mitsubishi'
    t.save!

    t=Make.find_by_id(12)
    t.ref='pinzgaur'
    t.save!

  end
end
