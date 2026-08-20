class Practitioner::GalleryImagesController < Practitioner::BaseController
  def index
  end

  def create
    files = Array(params[:gallery_images]).reject(&:blank?)
    if files.empty?
      redirect_to practitioner_gallery_images_path, alert: "Wählen Sie mindestens ein Bild zum Hochladen aus."
      return
    end

    remaining = Practitioner::MAX_GALLERY_IMAGES - @practitioner.gallery_images.count
    if files.size > remaining
      redirect_to practitioner_gallery_images_path,
                  alert: "Sie können noch #{helpers.pluralize(remaining, 'weiteres Bild', plural: 'weitere Bilder')} hinzufügen (maximal #{Practitioner::MAX_GALLERY_IMAGES} insgesamt)."
      return
    end

    invalid = files.find { |f| !valid_upload?(f) }
    if invalid
      redirect_to practitioner_gallery_images_path,
                  alert: "Jedes Bild muss JPEG, PNG oder WebP sein und darf höchstens 5 MB groß sein."
      return
    end

    existing_ids = @practitioner.gallery_images.attachments.pluck(:id)
    @practitioner.gallery_images.attach(files)
    new_ids = @practitioner.gallery_images.attachments.pluck(:id) - existing_ids
    @practitioner.update_column(:gallery_order, Array(@practitioner.gallery_order) + new_ids)

    redirect_to practitioner_gallery_images_path,
                notice: "#{helpers.pluralize(files.size, 'Bild', plural: 'Bilder')} zu Ihrer Galerie hinzugefügt."
  end

  def destroy
    attachment = @practitioner.gallery_images.attachments.find_by(id: params[:id])
    if attachment
      attachment.purge_later
      remaining_order = Array(@practitioner.gallery_order).map(&:to_i) - [attachment.id]
      @practitioner.update_column(:gallery_order, remaining_order)
      redirect_to practitioner_gallery_images_path, notice: "Bild entfernt."
    else
      redirect_to practitioner_gallery_images_path, alert: "Bild nicht gefunden."
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
