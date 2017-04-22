class UpdateCarDetails < ActiveRecord::Migration[5.0]
  def up
    t=Car.find_by_id(13)
    t.car_model='Defender 90'
    t.save!


    t=Car.find_by_id(25)
    t.car_model='Defender 110'
    t.save!

    t=Car.find_by_id(26)
    t.car_model='Defender 110'
    t.save!

    t=Car.find_by_id(32)
    t.car_model='Defender 90'
    t.colour='Cream'
    t.save!

    t=Car.find_by_id(45)
    t.car_model='Defender 110'
    t.save!

    t=Car.find_by_id(47)
    t.car_model='Series III'
    t.save!

    t=Car.find_by_id(40)
    t.car_model='Series III Lightweight'
    t.save!

    t=Car.find_by_id(55)
    t.car_model='Series III'
    t.save!


    t=Car.find_by_id(16)
    t.colour='Black'
    t.save!

    t=Car.find_by_id(55)
    t.car_model='Landruiser Pickup'
    t.save!

    t=Car.find_by_id(28)
    t.car_model='Landruiser 80 Series'
    t.save!

    t=Car.find_by_id(2)
    t.car_model='Landruiser 80 Series'
    t.save!

  end
end
