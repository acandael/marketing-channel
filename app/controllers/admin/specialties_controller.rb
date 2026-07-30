class Admin::SpecialtiesController < Admin::BaseController
  before_action :set_specialty, only: [:edit, :update, :destroy]

  def index
    @specialties = Specialty.alphabetical
  end

  def new
    @specialty = Specialty.new
  end

  def create
    @specialty = Specialty.new(specialty_params)
    if @specialty.save
      redirect_to admin_specialties_path, notice: "Specialty “#{@specialty.name}” created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @specialty.update(specialty_params)
      redirect_to admin_specialties_path, notice: "Specialty “#{@specialty.name}” updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @specialty.in_use?
      count = @specialty.usage_count
      suffix = count == 1 ? "practitioner" : "practitioners"
      redirect_to admin_specialties_path,
                  alert: "“#{@specialty.name}” is assigned to #{count} #{suffix} and can't be deleted. Remove the assignments first."
    else
      @specialty.destroy
      redirect_to admin_specialties_path, notice: "Specialty deleted."
    end
  end

  private

  def set_specialty
    @specialty = Specialty.find(params[:id])
  end

  def specialty_params
    params.expect(specialty: [:name, :description])
  end
end
