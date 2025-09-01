class CartsController < ApplicationController
  before_action :find_product, only: [:add_item, :remove_item]
  before_action :find_cart_by_session, only: [:remove_item]
  before_action :set_session_id_header

  # GET /cart
  def show
    @cart = Cart.find_by(session_id: current_session_id)
    
    unless @cart
      return render json: { error: 'Cart not found' }, status: :not_found
    end
    
    render json: {
      id: @cart.id,
      products: @cart.cart_items.includes(:product).map do |cart_item|
        {
          id: cart_item.product.id,
          name: cart_item.product.name,
          quantity: cart_item.quantity,
          unit_price: cart_item.product.price,
          total_price: cart_item.total_price
        }
      end,
      total_price: @cart.total_price
    }
  end

  
  # POST /cart
  def create
    begin
      unless params[:product_id].present?
        return render json: { error: 'Product ID is required' }, status: :bad_request
      end
      
      @product = Product.find(params[:product_id])
      quantity = params[:quantity]&.to_i || 1
      
      session_id = current_session_id
      
      @cart = Cart.create!(session_id: session_id, total_price: 0)
      
      event_store.publish(
        CartCreated.new(data: {
          cart_id: @cart.id,
          session_id: @cart.session_id,
          created_at: @cart.created_at
        })
      )
      
      @cart.add_product(@product, quantity)
      
      event_store.publish(
        ItemAddedToCart.new(data: {
          id: @cart.id,
          product_id: @product.id,
          quantity: quantity,
          product_name: @product.name,
          product_price: @product.price.to_f,
          session_id: @cart.session_id,
          added_at: Time.current
        })
      )
      
      render json: {
        cart_id: @cart.id,
        message: 'Cart created and item added successfully',
        products: @cart.products_list,
        total_price: @cart.total_price
      }, status: :created
    rescue ActiveRecord::RecordNotFound
      render json: { error: 'Product not found' }, status: :not_found
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /cart/add_item
  def add_item
    begin
      @cart = Cart.find_by(session_id: current_session_id)
      
      unless @cart
        return render json: { error: 'Cart not found. Please create a cart first.' }, status: :not_found
      end
      
      quantity = params[:quantity]&.to_i || 1
      
      if quantity <= 0
        return render json: { error: 'Quantity must be greater than 0' }, status: :unprocessable_entity
      end
      
      @cart.add_product(@product, quantity)
      
      event_store.publish(
        ItemAddedToCart.new(data: {
          id: @cart.id,
          product_id: @product.id,
          quantity: quantity,
          product_name: @product.name,
          product_price: @product.price.to_f,
          session_id: @cart.session_id,
          added_at: Time.current
        })
      )
      
      response.headers['X-Session-ID'] = @cart.session_id
      render json: {
        cart_id: @cart.id,
        message: 'Item added to cart successfully',
        products: @cart.products_list,
        total_price: @cart.total_price
      }, status: :created
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /cart/:product_id
  def remove_item
    unless @cart
      return render json: { error: 'Cart not found' }, status: :not_found
    end
    
    cart_item = @cart.cart_items.find_by(product: @product)
    unless cart_item
      return render json: { error: 'Product not found in cart' }, status: :not_found
    end
    
    removed_quantity = cart_item.quantity
    
    @cart.remove_product(@product)
    
    event_store.publish(
      ItemRemovedFromCart.new(data: {
        id: @cart.id,
        product_id: @product.id,
        quantity: removed_quantity,
        product_name: @product.name,
        product_price: @product.price.to_f,
        session_id: @cart.session_id,
        removed_at: Time.current
      })
    )
    
    render json: {
      cart_id: @cart.id,
      products: @cart.products_list,
      total_price: @cart.total_price
    }
  end

  private

  def generate_session_id
    request.headers['X-Session-ID'] || SecureRandom.hex(16)
  end

  def event_store
    Rails.configuration.event_store
  end

  def find_cart_by_session
    @cart = Cart.find_by(session_id: current_session_id)
  end

  def find_cart_by_id
    cart_id = params[:id] || params[:cart_id]
    
    if cart_id.present?
      @cart = Cart.find(cart_id)
    else
      render json: { error: 'Cart ID is required' }, status: :bad_request
      return
    end
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Cart not found' }, status: :not_found
  end

  def find_product
    @product = Product.find(params[:product_id])
  rescue ActiveRecord::RecordNotFound
    render json: { error: 'Product not found' }, status: :not_found
  end

  def add_item_params
    params.permit(:product_id, :quantity, :cart_id, :session_id)
  end

  def update_item_params
    params.permit(:quantity)
  end
end
