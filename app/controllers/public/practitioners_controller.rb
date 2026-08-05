class Public::PractitionersController < Public::BaseController
  def show
    @practitioner = Practitioner.includes(:specialty, :focus_areas, :treatments)
                                .with_attached_profile_photo
                                .with_attached_gallery_images
                                .find_by!(slug: params[:slug])

    @preview = !@practitioner.published?
    raise ActiveRecord::RecordNotFound if @preview && !viewer_owns_practitioner?
  end

  private

  def viewer_owns_practitioner?
    Current.user&.practitioner&.id == @practitioner.id
  end
end
