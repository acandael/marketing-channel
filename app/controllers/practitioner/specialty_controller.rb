class Practitioner::SpecialtyController < Practitioner::BaseController
  def edit
    @specialties = Specialty.alphabetical
    @suggested_focus_areas = FocusArea.alphabetical
  end

  def update
    @practitioner.specialty_id = params.dig(:practitioner, :specialty_id).presence

    focus_area_ids = normalize_focus_areas(params.dig(:practitioner, :focus_area_names))
    @practitioner.focus_area_ids = focus_area_ids

    if @practitioner.save
      redirect_to edit_practitioner_specialty_path, notice: "Specialty and focus areas saved."
    else
      @specialties = Specialty.alphabetical
      @suggested_focus_areas = FocusArea.alphabetical
      render :edit, status: :unprocessable_content
    end
  end

  private

  def normalize_focus_areas(raw)
    names = Array(raw).flat_map { |val| val.to_s.split(",") }
                     .map { |n| n.strip.squeeze(" ") }
                     .reject(&:blank?)
                     .uniq { |n| n.downcase }

    names.filter_map { |name| FocusArea.find_or_create_by_name(name)&.id }
  end
end
