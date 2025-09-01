require 'rails_helper'

RSpec.describe "/carts", type: :request do
  describe "POST /cart" do
    let!(:product) { Product.create(name: "Test Product", price: 10.0) }
    
    context 'when creating a new cart with a product' do
      it 'creates a new cart and adds the product' do
        expect {
          post '/cart', params: { product_id: product.id, quantity: 2 }, as: :json
        }.to change(Cart, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to be_present
        expect(json_response['products']).to be_an(Array)
        expect(json_response['products'].first['id']).to eq(product.id)
        expect(json_response['products'].first['name']).to eq("Test Product")
        expect(json_response['products'].first['quantity']).to eq(2)
        expect(json_response['products'].first['unit_price']).to eq(10.0)
        expect(json_response['products'].first['total_price']).to eq(20.0)
        expect(json_response['total_price']).to eq(20.0)
      end
    end
    
    context 'when creating a cart without a product' do
      it 'creates an empty cart' do
        expect {
          post '/cart', params: {}, as: :json
        }.to change(Cart, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to be_present
        expect(json_response['products']).to eq([])
        expect(json_response['total_price'].to_f).to eq(0.0)
      end
    end
    
    context 'when product does not exist' do
      it 'returns not found error' do
        post '/cart', params: { product_id: 999, quantity: 1 }, as: :json
        
        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Product not found')
      end
    end
    
    context 'when quantity is not provided' do
      it 'defaults to quantity 1' do
        post '/cart', params: { product_id: product.id }, as: :json
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['products'].first['quantity']).to eq(1)
      end
    end
  end
  
  describe "POST /cart/add_item" do
    let!(:product) { Product.create(name: "Test Product", price: 10.0) }
    let!(:another_product) { Product.create(name: "Another Product", price: 15.0) }
    
    context 'when cart does not exist' do
      it 'creates a new cart and adds the product' do
        expect {
          post '/cart/add_item', params: { product_id: product.id, quantity: 2 }, as: :json
        }.to change(Cart, :count).by(1)
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['cart_id']).to be_present
        expect(json_response['message']).to eq('Item added to cart successfully')
        expect(json_response['products']).to be_an(Array)
        expect(json_response['products'].first['id']).to eq(product.id)
        expect(json_response['products'].first['quantity']).to eq(2)
        expect(json_response['total_price']).to eq(20.0)
      end
    end
    
    context 'when cart already exists' do
      let!(:cart) { Cart.create(session_id: 'test_session', total_price: 0) }
      
      it 'adds product to existing cart' do
        expect {
          post '/cart/add_item', params: { cart_id: cart.id, product_id: product.id, quantity: 1 }, as: :json
        }.not_to change(Cart, :count)
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['cart_id']).to eq(cart.id)
        expect(json_response['message']).to eq('Item added to cart successfully')
      end
    end
    
    context 'when product already exists in cart' do
      let!(:cart) { Cart.create(session_id: 'test_session', total_price: 0) }
      
      before do
        cart.add_product(product, 1)
      end
      
      it 'increases the quantity of existing product' do
        post '/cart/add_item', params: { cart_id: cart.id, product_id: product.id, quantity: 2 }, as: :json
        
        expect(response).to have_http_status(:created)
        
        cart_item = cart.cart_items.find_by(product: product)
        expect(cart_item.quantity).to eq(3)
      end
    end
    
    context 'when quantity is zero or negative' do
      it 'returns unprocessable entity error' do
        post '/cart/add_item', params: { product_id: product.id, quantity: 0 }, as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['errors']).to include('Quantity must be greater than 0')
      end
    end
    
    context 'when product does not exist' do
      it 'returns not found error' do
        post '/cart/add_item', params: { product_id: 999, quantity: 1 }, as: :json
        
        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Product not found')
      end
    end
  end
  
  describe "GET /cart" do
    let!(:cart) { Cart.create(session_id: 'test_session', total_price: 0) }
    let!(:product1) { Product.create(name: "Product 1", price: 10.0) }
    let!(:product2) { Product.create(name: "Product 2", price: 15.0) }
    
    before do
      cart.add_product(product1, 2)
      cart.add_product(product2, 1)
    end
    
    it 'returns cart details with products' do
        get '/cart', params: { cart_id: cart.id }, as: :json
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to eq(cart.id)
        expect(json_response['products']).to be_an(Array)
        expect(json_response['products'].length).to eq(2)
        expect(json_response['total_price']).to eq(35.0)
      end
    
    context 'when cart does not exist' do
      it 'returns not found error' do
         get '/cart', params: { cart_id: 999 }, as: :json
         
         expect(response).to have_http_status(:not_found)
         
         json_response = JSON.parse(response.body)
         expect(json_response['error']).to eq('Cart not found')
       end
    end
  end
  
  describe "DELETE /cart/:product_id" do
    let!(:cart) { Cart.create(session_id: 'test_session', total_price: 0) }
    let!(:product) { Product.create(name: "Test Product", price: 10.0) }
    
    before do
      cart.add_product(product, 2)
    end
    
    it 'removes product from cart' do
       delete "/cart/#{product.id}", params: { cart_id: cart.id }, as: :json
       
       expect(response).to have_http_status(:ok)
       
       json_response = JSON.parse(response.body)
        expect(json_response['cart_id']).to eq(cart.id)
        expect(json_response['products']).to eq([])
        expect(json_response['total_price'].to_f).to eq(0.0)
     end
    
    context 'when product is not in cart' do
      let!(:another_product) { Product.create(name: "Another Product", price: 15.0) }
      
      it 'returns not found error' do
         delete "/cart/#{another_product.id}", params: { cart_id: cart.id }, as: :json
         
         expect(response).to have_http_status(:not_found)
         
         json_response = JSON.parse(response.body)
         expect(json_response['error']).to eq('Product not found in cart')
       end
    end
    
    context 'when cart does not exist' do
      it 'returns not found error' do
         delete "/cart/#{product.id}", params: { cart_id: 999 }, as: :json
         
         expect(response).to have_http_status(:not_found)
         
         json_response = JSON.parse(response.body)
         expect(json_response['error']).to eq('Cart not found')
       end
    end
  end
end
