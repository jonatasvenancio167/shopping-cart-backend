class CartItemService
  def self.validate_quantity(quantity)
    quantity_int = quantity&.to_i || 1
    
    if quantity_int <= 0
      raise ArgumentError, 'Quantity must be greater than 0'
    end
    
    quantity_int
  end

  def self.validate_product_id(product_id)
    unless product_id.present?
      raise ArgumentError, 'Product ID is required'
    end
    
    product_id
  end

  def self.find_cart_item(cart, product)
    cart.cart_items.find_by(product: product)
  end
end