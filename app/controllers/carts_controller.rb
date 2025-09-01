class CartsController < ApplicationController
  before_action :find_product, only: [:add_item, :remove_item]
  before_action :find_cart_by_session, only: [:remove_item]
  before_action :set_session_id_header

  # GET /cart
  def show
    cart_service = CartService.new(session_id: current_session_id)
    @cart = cart_service.find_cart
    
    unless @cart
      return render json: { error: 'Cart not found' }, status: :not_found
    end
    
    render json: CartSerializer.new(@cart).as_json
  end

  
  # POST /cart
  def create
    begin
      CartItemService.validate_product_id(params[:product_id])
      quantity = CartItemService.validate_quantity(params[:quantity])
      
      cart_service = CartService.new(session_id: current_session_id)
      @cart = cart_service.create_cart_with_product(
        product_id: params[:product_id],
        quantity: quantity
      )
      
      cart_data = CartSerializer.new(@cart).as_json_with_cart_id
      cart_data[:message] = 'Cart created and item added successfully'
      render json: cart_data, status: :created
    rescue ArgumentError => e
      render json: { error: e.message }, status: :bad_request
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :not_found
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # POST /cart/add_item
  def add_item
    begin
      cart_service = CartService.new(session_id: current_session_id)
      @cart = cart_service.find_cart
      
      unless @cart
        return render json: { error: 'Cart not found. Please create a cart first.' }, status: :not_found
      end
      
      quantity = CartItemService.validate_quantity(params[:quantity])
      
      @cart = cart_service.add_product_to_existing_cart(
        cart: @cart,
        product_id: @product.id,
        quantity: quantity
      )
      
      response.headers['X-Session-ID'] = @cart.session_id
      cart_data = CartSerializer.new(@cart).as_json_with_cart_id
      cart_data[:message] = 'Item added to cart successfully'
      render json: cart_data, status: :created
    rescue ArgumentError => e
      render json: { error: e.message }, status: :unprocessable_entity
    rescue ActiveRecord::RecordInvalid => e
      render json: { errors: e.record.errors.full_messages }, status: :unprocessable_entity
    end
  end

  # DELETE /cart/:product_id
  def remove_item
    begin
      unless @cart
        return render json: { error: 'Cart not found' }, status: :not_found
      end
      
      cart_service = CartService.new(session_id: current_session_id)
      @cart = cart_service.remove_product_from_cart(
        cart: @cart,
        product_id: @product.id
      )
      
      render json: CartSerializer.new(@cart).as_json_with_cart_id
    rescue ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :not_found
    end
  end

  private

  def generate_session_id
    request.headers['X-Session-ID'] || SecureRandom.hex(16)
  end

  def find_cart_by_session
    cart_service = CartService.new(session_id: current_session_id)
    @cart = cart_service.find_cart
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
