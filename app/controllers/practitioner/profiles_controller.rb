class Practitioner::ProfilesController < Practitioner::BaseController
  def edit
    @specialties = Specialty.alphabetical
  end

  def update
    if @practitioner.update(profile_params)
      redirect_to edit_practitioner_profile_path, notice: "Profile saved."
    else
      @specialties = Specialty.alphabetical
      render :edit, status: :unprocessable_content
    end
  end

  def publish
    @practitioner.update!(published: true)
    redirect_to practitioner_root_path, notice: "Your profile is now visible on the directory."
  end

  def unpublish
    @practitioner.update!(published: false)
    redirect_to practitioner_root_path, notice: "Your profile is hidden from the directory."
  end

  private

  def profile_params
    opening_hours_permit = Practitioner::DAYS_OF_WEEK.index_with { [:open, :close, :closed] }

    params.require(:practitioner).permit(
      :salutation, :full_name, :street_address, :postal_code, :city, :bundesland,
      :phone, :public_email, :website_url, :latitude, :longitude,
      :short_tagline, :long_bio, :languages_spoken, :qualifications,
      :years_in_practice, :profile_photo,
      specialty_ids: [],
      gallery_images: [],
      opening_hours: opening_hours_permit
    )
  end
end
