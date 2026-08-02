class Practitioner::GalleryImagesController < Practitioner::BaseController
  def index
  end

  def create
    files = Array(params[:gallery_images]).reject(&:blank?)
    if files.empty?
      redirect_to practitioner_gallery_images_path, alert: "Choose at least one image to upload."
      return
    end

    remaining = Practitioner::MAX_GALLERY_IMAGES - @practitioner.gallery_images.count
    if files.size > remaining
      redirect_to practitioner_gallery_images_path,
                  alert: "You can add #{helpers.pluralize(remaining, 'more image')} (max #{Practitioner::MAX_GALLERY_IMAGES} total)."
      return
    end

    invalid = files.find { |f| !valid_upload?(f) }
    if invalid
      redirect_to practitioner_gallery_images_path,
                  alert: "Each image must be JPEG, PNG, or WebP and under 5 MB."
      return
    end

    existing_ids = @practitioner.gallery_images.attachments.pluck(:id)
    @practitioner.gallery_images.attach(files)
    new_ids = @practitioner.gallery_images.attachments.pluck(:id) - existing_ids
    @practitioner.update_column(:gallery_order, Array(@practitioner.gallery_order) + new_ids)

    redirect_to practitioner_gallery_images_path,
                notice: "#{helpers.pluralize(files.size, 'image')} added to your gallery."
  end

  def destroy
    attachment = @practitioner.gallery_images.attachments.find_by(id: params[:id])
    if attachment
      attachment.purge_later
      remaining_order = Array(@practitioner.gallery_order).map(&:to_i) - [attachment.id]
      @practitioner.update_column(:gallery_order, remaining_order)
      redirect_to practitioner_gallery_images_path, notice: "Image removed."
    else
      redirect_to practitioner_gallery_images_path, alert: "Image not found."
    end
  end

  def reorder
    submitted = Array(params[:order]).map(&:to_i)
    valid_ids = @practitioner.gallery_images.attachments.pluck(:id)
    new_order = submitted & valid_ids
    @practitioner.update_column(:gallery_order, new_order)
    head :no_content
  end

  private

  def valid_upload?(file)
    return false unless file.respond_to?(:content_type) && file.respond_to?(:size)
    return false unless Practitioner::ALLOWED_IMAGE_TYPES.include?(file.content_type)
    return false if file.size > Practitioner::MAX_IMAGE_BYTES
    true
  end
end
