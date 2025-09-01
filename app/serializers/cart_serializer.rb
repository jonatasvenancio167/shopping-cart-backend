class CartSerializer
  def initialize(cart)
    @cart = cart
  end

  def as_json
    {
      id: @cart.id,
      products: serialized_products,
      total_price: @cart.total_price
    }
  end

  def as_json_with_cart_id
    {
      cart_id: @cart.id,
      products: serialized_products,
      total_price: @cart.total_price
    }
  end

  private

  def serialized_products
    @cart.cart_items.includes(:product).map do |cart_item|
      CartItemSerializer.new(cart_item).as_json
    end
  end
end