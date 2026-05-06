class DashboardController < ApplicationController
  def show
    redirect_to growth_cycles_path if current_user.growth_cycles.any?
  end
end
