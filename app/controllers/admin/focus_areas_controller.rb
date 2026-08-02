class Admin::FocusAreasController < Admin::BaseController
  before_action :set_focus_area, only: [:edit, :update, :destroy]

  def index
    @focus_areas = FocusArea.alphabetical
  end

  def new
    @focus_area = FocusArea.new
  end

  def create
    @focus_area = FocusArea.new(focus_area_params)
    if @focus_area.save
      redirect_to admin_focus_areas_path, notice: "Focus area “#{@focus_area.name}” created."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @focus_area.update(focus_area_params)
      redirect_to admin_focus_areas_path, notice: "Focus area “#{@focus_area.name}” updated."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    if @focus_area.in_use?
      count = @focus_area.usage_count
      suffix = count == 1 ? "practitioner" : "practitioners"
      redirect_to admin_focus_areas_path,
                  alert: "“#{@focus_area.name}” is used by #{count} #{suffix} and can't be deleted."
    else
      @focus_area.destroy
      redirect_to admin_focus_areas_path, notice: "Focus area deleted."
    end
  end

  private

  def set_focus_area
    @focus_area = FocusArea.find(params[:id])
  end

  def focus_area_params
    params.expect(focus_area: [:name])
  end
end
