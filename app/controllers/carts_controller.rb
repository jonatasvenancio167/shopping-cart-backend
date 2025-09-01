class CartsController < ApplicationController
  before_action :find_cart_by_id, only: [:show, :remove_item]
  before_action :find_product, only: [:add_item, :remove_item]

  # GET /cart
  def show
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
    session_id = session.id.to_s.presence || SecureRandom.hex(16)
    @cart = Cart.find_by(session_id: session_id)
    
    if @cart.nil?
      @cart = Cart.new(session_id: session_id)
      @cart.total_price = 0
      
      unless @cart.save
        render json: { errors: @cart.errors.full_messages }, status: :unprocessable_entity
        return
      end
      
      session[:cart_id] = @cart.id
      
      event_store.publish(
        CartCreated.new(data: {
          cart_id: @cart.id,
          session_id: @cart.session_id,
          created_at: @cart.created_at
        })
      )
    end
    
    if params[:product_id].present?
      product = Product.find_by(id: params[:product_id])
      
      if product.nil?
        render json: { error: 'Product not found' }, status: :not_found
        return
      end
      
      quantity = params[:quantity] || 1
      cart_item = @cart.cart_items.find_by(product: product)
      
      if cart_item
        cart_item.quantity += quantity.to_i
        cart_item.save!
      else
        @cart.cart_items.create!(product: product, quantity: quantity.to_i)
      end
      
      event_store.publish(
        ItemAddedToCart.new(data: {
          cart_id: @cart.id,
          product_id: product.id,
          product_name: product.name,
          quantity: quantity.to_i,
          unit_price: product.price.to_f
        })
      )
    end
    
    render json: {
      id: @cart.id,
      products: @cart.cart_items.includes(:product).map do |item|
        {
          id: item.product.id,
          name: item.product.name,
          quantity: item.quantity,
          unit_price: item.product.price.to_f,
          total_price: (item.product.price * item.quantity).to_f
        }
      end,
      total_price: @cart.cart_items.joins(:product).sum('products.price * cart_items.quantity').to_f
    }, status: :created
  end

  # POST /cart/add_item
  def add_item
    quantity = add_item_params[:quantity] || 1
    cart_id = add_item_params[:cart_id]
    
    if quantity <= 0
      return render json: { errors: ['Quantity must be greater than 0'] }, status: :unprocessable_entity
    end
    
    begin
      if cart_id.present?
        @cart = Cart.find(cart_id)
        cart_created = false
      else
        session_id = session.id.to_s.presence || SecureRandom.hex(16)
        @cart = Cart.find_by(session_id: session_id)
        
        if @cart.nil?
          @cart = Cart.create!(session_id: session_id, total_price: 0)
          session[:cart_id] = @cart.id
          cart_created = true
        else
          cart_created = false
        end
      end
      
      @cart.add_product(@product, quantity)
      
      event_store.publish(
        CartCreated.new(data: {
          cart_id: @cart.id,
          session_id: @cart.session_id,
          created_at: @cart.created_at
        })
      )
      
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

  def event_store
    Rails.configuration.event_store
  end

  def find_cart_by_id
    cart_id = params[:id] || params[:cart_id] || session[:cart_id]
    
    if cart_id.present?
      @cart = Cart.find(cart_id)
    else
      render json: { error: 'No active cart found' }, status: :not_found
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
    params.permit(:product_id, :quantity, :cart_id)
  end

  def update_item_params
    params.permit(:quantity)
  end
end
