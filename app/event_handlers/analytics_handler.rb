class AnalyticsHandler
  def call(event)
    case event
    when CartCreated
      track_cart_creation(event)
    when ItemAddedToCart
      track_item_added(event)
    when ItemRemovedFromCart
      track_item_removed(event)
    end
  end

  private

  def track_cart_creation(event)
    Rails.logger.info "[ANALYTICS] Cart created: #{event.data[:cart_id]} for session #{event.data[:session_id]}"
  end

  def track_item_added(event)
    Rails.logger.info "[ANALYTICS] Item added to cart: #{event.data[:product_name]} (#{event.data[:quantity]}x) - Cart: #{event.data[:cart_id]}"
  end

  def track_item_removed(event)
    Rails.logger.info "[ANALYTICS] Item removed from cart: #{event.data[:product_name]} (#{event.data[:quantity]}x) - Cart: #{event.data[:cart_id]}"
  end
end