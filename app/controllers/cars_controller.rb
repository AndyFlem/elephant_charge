class CarsController < ApplicationController
  def index
    @cars = Car.order(:name)
  end

  def show
    @car = Car.find(params[:id])
  end

  def new
    @car=Car.new()
    @makes=Make.all.collect{|p| [ p.name, p.id ] }
  end

  def edit
    @car = Car.find(params[:id])
    @makes=Make.all.collect{|p| [ p.name, p.id ] }
    @entries=@car.entries
    @photos=@car.photos
  end

  def create
      @car = Car.new(car_params)

      if @car.save
        redirect_to cars_path
      else
        @makes=Make.all.collect{|p| [ p.name, p.id ] }
        render 'new'
      end
  end

  def destroy
    @car= Car.find(params[:id])
    begin
      @car.destroy
      redirect_to cars_path
    rescue
      redirect_to cars_path,:flash => { :error => "Cant delete car which is entered in a charge." }
    end
  end

  def update
    @car = Car.find(params[:id])

    if @car.update(car_params)
      redirect_to cars_path
    else
      @makes=Make.all.collect{|p| [ p.name, p.id ] }
      render 'edit'
    end
  end

  private
  def car_params
    params.require(:car).permit(:name, :car_model, :colour, :year, :make_id)
  end
end
