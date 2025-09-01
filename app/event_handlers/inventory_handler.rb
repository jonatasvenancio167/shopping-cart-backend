class InventoryHandler
  def call(event)
    case event
    when ItemAddedToCart
      reserve_inventory(event)
    when ItemRemovedFromCart
      release_inventory(event)
    end
  end

  private

  def reserve_inventory(event)
    Rails.logger.info "[INVENTORY] Reserving #{event.data[:quantity]} units of product #{event.data[:product_id]} for cart #{event.data[:cart_id]}"
  end

  def release_inventory(event)
    Rails.logger.info "[INVENTORY] Releasing #{event.data[:quantity]} units of product #{event.data[:product_id]} from cart #{event.data[:cart_id]}"
  end
end