class Public::HomeController < Public::BaseController
  def index
    @filters = params.permit(:q, :near).to_h.symbolize_keys

    scope = Practitioner.published
                        .includes(:specialty, :focus_areas)
                        .with_attached_profile_photo
                        .by_query(@filters[:q])
                        .by_location(@filters[:near])
                        .order(Arel.sql("LOWER(full_name)"))

    @searching = @filters[:q].present? || @filters[:near].present?
    @pagy, @practitioners = pagy(scope, limit: 12)
  end
end
