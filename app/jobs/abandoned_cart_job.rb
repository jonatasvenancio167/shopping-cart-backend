class AbandonedCartJob < ApplicationJob
  queue_as :default

  def perform
    abandoned_threshold = 3.hours.ago
    Cart.active.old_interactions(abandoned_threshold).find_each do |cart|
      cart.mark_as_abandoned!
      Rails.logger.info "Cart #{cart.id} marked as abandoned"
    end

    removal_threshold = 7.days.ago
    abandoned_carts = Cart.abandoned.where('abandoned_at < ?', removal_threshold)
    
    abandoned_carts.find_each do |cart|
      Rails.logger.info "Removing abandoned cart #{cart.id}"
      cart.destroy
    end

    Rails.logger.info "Abandoned cart cleanup completed"
  end
end