class BeneficiariesController < ApplicationController

    def index
      @beneficiaries = Beneficiary.order(:name)
    end

    def show
      @beneficiary = Beneficiary.find(params[:id])
    end

    def new
      @beneficiary=Beneficiary.new()
    end

    def edit
      @beneficiary = Beneficiary.find(params[:id])
    end

    def create
      @beneficiary = Beneficiary.new(beneficiary_params)
      if @beneficiary.short_name==""
        @beneficiary.short_name=nil
      end

      if @beneficiary.save
        redirect_to beneficiaries_path
      else
        render 'new'
      end
    end

    def destroy
      @beneficiary= Beneficiary.find(params[:id])
      begin
        @beneficiary.destroy
        redirect_to beneficiaries_path
      rescue
        redirect_to beneficiaries_path,:flash => { :error => "Cant delete beneficiary." }
      end
    end

    def uploadlogo
      beneficiary= Beneficiary.find(params[:id])
      beneficiary.logo=params[:logo]
      beneficiary.save!
      redirect_to beneficiaries_path
    end

    def update
      @beneficiary= Beneficiary.find(params[:id])

      if @beneficiary.update(beneficiary_params)
        redirect_to beneficiaries_path
      else
        render 'edit'
      end
    end

    private
    def beneficiary_params
      params.require(:beneficiary).permit(:name,:short_name,:logo,:geography,:geography_description,:description,:website,:facebook)
    end

end