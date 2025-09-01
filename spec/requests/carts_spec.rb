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
        expect(json_response['cart_id']).to be_present
        expect(json_response['products']).to be_an(Array)
        expect(json_response['products'].first['id']).to eq(product.id)
        expect(json_response['products'].first['name']).to eq("Test Product")
        expect(json_response['products'].first['quantity']).to eq(2)
        expect(json_response['products'].first['unit_price']).to eq("10.0")
        expect(json_response['products'].first['total_price']).to eq("20.0")
        expect(json_response['total_price']).to eq("20.0")
      end
    end
    
    context 'when creating a cart without a product' do
      it 'returns bad request error' do
        post '/cart', params: {}, as: :json
        
        expect(response).to have_http_status(:bad_request)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Product ID is required')
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
      it 'returns not found error' do
        post '/cart/add_item', params: { product_id: product.id, quantity: 2 }, as: :json
        
        expect(response).to have_http_status(:not_found)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Cart not found. Please create a cart first.')
      end
    end
    
    context 'when cart already exists' do
      before do
        post '/cart', params: { product_id: another_product.id, quantity: 1 }, as: :json
      end
      
      it 'adds product to existing cart' do
        expect {
          post '/cart/add_item', params: { product_id: product.id, quantity: 1 }, as: :json
        }.not_to change(Cart, :count)
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['cart_id']).to be_present
        expect(json_response['products'].length).to eq(2)
      end
    end
    
    context 'when product already exists in cart' do
      before do
        # Cria carrinho com produto inicial
        post '/cart', params: { product_id: product.id, quantity: 1 }, as: :json
      end
      
      it 'increases the quantity of existing product' do
        post '/cart/add_item', params: { product_id: product.id, quantity: 2 }, as: :json
        
        expect(response).to have_http_status(:created)
        
        json_response = JSON.parse(response.body)
        expect(json_response['products'].first['quantity']).to eq(3)
      end
    end
    
    context 'when quantity is zero or negative' do
      it 'returns unprocessable entity error' do
        # Cria carrinho primeiro
        post '/cart', params: { product_id: product.id, quantity: 1 }, as: :json
        
        post '/cart/add_item', params: { product_id: product.id, quantity: 0 }, as: :json
        
        expect(response).to have_http_status(:unprocessable_entity)
        
        json_response = JSON.parse(response.body)
        expect(json_response['error']).to eq('Quantity must be greater than 0')
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
    let!(:product1) { Product.create(name: "Product 1", price: 10.0) }
    let!(:product2) { Product.create(name: "Product 2", price: 15.0) }
    
    before do
      post '/cart', params: { product_id: product1.id, quantity: 2 }, as: :json
      post '/cart/add_item', params: { product_id: product2.id, quantity: 1 }, as: :json
    end
    
    it 'returns cart details with products' do
        get '/cart', as: :json
        
        expect(response).to have_http_status(:ok)
        
        json_response = JSON.parse(response.body)
        expect(json_response['id']).to be_present
        expect(json_response['products']).to be_an(Array)
        expect(json_response['products'].length).to eq(2)
        expect(json_response['total_price']).to eq("35.0")
      end
    
    context 'when cart does not exist' do
      it 'returns not found error' do
         # Simula uma nova sessão sem carrinho
         allow_any_instance_of(CartsController).to receive(:current_session_id).and_return('new_session_without_cart')
         get '/cart', as: :json
         
         expect(response).to have_http_status(:not_found)
         
         json_response = JSON.parse(response.body)
         expect(json_response['error']).to eq('Cart not found')
       end
    end
  end
  
  describe "DELETE /cart/:product_id" do
    let!(:product) { Product.create(name: "Test Product", price: 10.0) }
    
    before do
      post '/cart', params: { product_id: product.id, quantity: 2 }, as: :json
    end
    
    it 'removes product from cart' do
       delete "/cart/#{product.id}", as: :json
       
       expect(response).to have_http_status(:ok)
       
       json_response = JSON.parse(response.body)
        expect(json_response['cart_id']).to be_present
        expect(json_response['products']).to eq([])
        expect(json_response['total_price']).to eq("0.0")
     end
    
    context 'when product is not in cart' do
      let!(:another_product) { Product.create(name: "Another Product", price: 15.0) }
      
      it 'returns not found error' do
         delete "/cart/#{another_product.id}", as: :json
         
         expect(response).to have_http_status(:not_found)
         
         json_response = JSON.parse(response.body)
         expect(json_response['error']).to eq('Product not found in cart')
       end
    end
    
    context 'when cart does not exist' do
      it 'returns not found error' do
         # Simula uma nova sessão sem carrinho
         allow_any_instance_of(CartsController).to receive(:current_session_id).and_return('new_session_without_cart')
         delete "/cart/#{product.id}", as: :json
         
         expect(response).to have_http_status(:not_found)
         
         json_response = JSON.parse(response.body)
         expect(json_response['error']).to eq('Cart not found')
       end
    end
  end
end
