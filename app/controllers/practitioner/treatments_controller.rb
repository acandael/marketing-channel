class Practitioner::TreatmentsController < Practitioner::BaseController
  before_action :set_treatment, only: [:edit, :update, :destroy]

  def index
    @treatments = @practitioner.treatments.ordered
  end

  def new
    @treatment = @practitioner.treatments.new
  end

  def create
    @treatment = @practitioner.treatments.new(treatment_params)
    if @treatment.save
      redirect_to practitioner_treatments_path, notice: "Treatment added."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @treatment.update(treatment_params)
      redirect_to practitioner_treatments_path, notice: "Treatment updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @treatment.destroy
    redirect_to practitioner_treatments_path, notice: "Treatment removed."
  end

  private

  def set_treatment
    @treatment = @practitioner.treatments.find(params[:id])
  end

  def treatment_params
    params.require(:treatment).permit(:title, :description, :duration_minutes, :price_euros)
  end
end
