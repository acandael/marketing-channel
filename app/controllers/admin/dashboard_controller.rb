class Admin::DashboardController < Admin::BaseController
  def index
    scope = Practitioner.all

    @total_count       = scope.count
    @published_count   = scope.published.count
    @unpublished_count = scope.unpublished.count
    @claimed_count     = scope.claimed.count
    @unclaimed_count   = scope.unclaimed.count

    @recent_practitioners = scope.order(updated_at: :desc).limit(5)
    @specialty_count = Specialty.count
  end
end
