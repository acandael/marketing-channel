class Public::PractitionersController < Public::BaseController
  def show
    @practitioner = Practitioner.published
                                .includes(:specialties, :treatments)
                                .with_attached_profile_photo
                                .with_attached_gallery_images
                                .find_by!(slug: params[:slug])
  end
end
