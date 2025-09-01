class NotificationHandler
  def call(event)
    case event
    when ItemAddedToCart
      check_for_recommendations(event)
    end
  end

  private

  def schedule_abandonment_email(event)
    Rails.logger.info "[NOTIFICATION] Scheduling abandonment email for cart #{event.data[:cart_id]}"
  end

  def check_for_recommendations(event)
    Rails.logger.info "[NOTIFICATION] Checking recommendations for product #{event.data[:product_name]}"
  end
end