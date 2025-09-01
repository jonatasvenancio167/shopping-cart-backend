class CartService
  def initialize(session_id:, event_store: Rails.configuration.event_store)
    @session_id = session_id
    @event_store = event_store
  end

  def find_cart
    Cart.find_by(session_id: @session_id)
  end

  def create_cart_with_product(product_id:, quantity: 1)
    product = Product.find(product_id)
    
    cart = Cart.create!(session_id: @session_id, total_price: 0)
    
    publish_cart_created_event(cart)
    
    add_product_to_cart(cart, product, quantity)
    
    cart
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordNotFound, 'Product not found'
  end

  def add_product_to_existing_cart(cart:, product_id:, quantity: 1)
    product = Product.find(product_id)
    
    add_product_to_cart(cart, product, quantity)
    
    cart
  rescue ActiveRecord::RecordNotFound
    raise ActiveRecord::RecordNotFound, 'Product not found'
  end

  def remove_product_from_cart(cart:, product_id:)
    product = Product.find(product_id)
    
    cart_item = cart.cart_items.find_by(product: product)
    raise ActiveRecord::RecordNotFound, 'Product not found in cart' unless cart_item
    
    removed_quantity = cart_item.quantity
    
    cart.remove_product(product)
    
    publish_item_removed_event(cart, product, removed_quantity)
    
    cart
  rescue ActiveRecord::RecordNotFound => e
    raise e
  end

  private

  def add_product_to_cart(cart, product, quantity)
    cart.add_product(product, quantity)
    
    publish_item_added_event(cart, product, quantity)
  end

  def publish_cart_created_event(cart)
    @event_store.publish(
      CartCreated.new(data: {
        cart_id: cart.id,
        session_id: cart.session_id,
        created_at: cart.created_at
      })
    )
  end

  def publish_item_added_event(cart, product, quantity)
    @event_store.publish(
      ItemAddedToCart.new(data: {
        id: cart.id,
        product_id: product.id,
        quantity: quantity,
        product_name: product.name,
        product_price: product.price.to_f,
        session_id: cart.session_id,
        added_at: Time.current
      })
    )
  end

  def publish_item_removed_event(cart, product, quantity)
    @event_store.publish(
      ItemRemovedFromCart.new(data: {
        id: cart.id,
        product_id: product.id,
        quantity: quantity,
        product_name: product.name,
        product_price: product.price.to_f,
        session_id: cart.session_id,
        removed_at: Time.current
      })
    )
  end
end