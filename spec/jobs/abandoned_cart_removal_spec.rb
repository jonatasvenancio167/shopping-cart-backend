require 'rails_helper'

RSpec.describe 'Abandoned Cart Removal', type: :job do
  let!(:product) { Product.create(name: "Test Product", price: 10.0) }
  
  describe 'removing carts abandoned for more than 7 days' do
    context 'when carts are abandoned for different periods' do
      let!(:recently_abandoned_cart) { Cart.create(session_id: "recent_abandoned", total_price: 0, abandoned_at: 3.days.ago) }
      let!(:old_abandoned_cart) { Cart.create(session_id: "old_abandoned", total_price: 0, abandoned_at: 8.days.ago) }
      let!(:very_old_abandoned_cart) { Cart.create(session_id: "very_old_abandoned", total_price: 0, abandoned_at: 15.days.ago) }
      let!(:active_cart) { Cart.create(session_id: "active", total_price: 0) }
      
      before do
        recently_abandoned_cart.add_product(product, 1)
        old_abandoned_cart.add_product(product, 2)
        very_old_abandoned_cart.add_product(product, 3)
        active_cart.add_product(product, 1)
      end
      
      it 'removes only carts abandoned for more than 7 days' do
        expect {
          AbandonedCartJob.new.perform
        }.to change { Cart.count }.by(-2)
        
        expect(Cart.exists?(recently_abandoned_cart.id)).to be true
        expect(Cart.exists?(old_abandoned_cart.id)).to be false
        expect(Cart.exists?(very_old_abandoned_cart.id)).to be false
        expect(Cart.exists?(active_cart.id)).to be true
      end
      
      it 'removes associated cart items when removing abandoned carts' do
        old_cart_items = old_abandoned_cart.cart_items.count
        very_old_cart_items = very_old_abandoned_cart.cart_items.count
        
        expect {
          AbandonedCartJob.new.perform
        }.to change { CartItem.count }.by(-(old_cart_items + very_old_cart_items))
      end
      
      it 'logs the removal of each old abandoned cart' do
        allow(Rails.logger).to receive(:info)
        
        AbandonedCartJob.new.perform
        
        expect(Rails.logger).to have_received(:info).with("Removing abandoned cart #{old_abandoned_cart.id}")
        expect(Rails.logger).to have_received(:info).with("Removing abandoned cart #{very_old_abandoned_cart.id}")
        expect(Rails.logger).not_to have_received(:info).with("Removing abandoned cart #{recently_abandoned_cart.id}")
      end
    end
    
    context 'when no carts need removal' do
      let!(:recently_abandoned_cart) { Cart.create(session_id: "recent_abandoned", total_price: 0, abandoned_at: 3.days.ago) }
      let!(:active_cart) { Cart.create(session_id: "active", total_price: 0) }
      
      before do
        recently_abandoned_cart.add_product(product, 1)
        active_cart.add_product(product, 1)
      end
      
      it 'does not remove any carts' do
        expect {
          AbandonedCartJob.new.perform
        }.not_to change { Cart.count }
      end
      
      it 'still logs completion' do
        allow(Rails.logger).to receive(:info)
        
        AbandonedCartJob.new.perform
        
        expect(Rails.logger).to have_received(:info).with("Abandoned cart cleanup completed")
        expect(Rails.logger).not_to have_received(:info).with(include("Removing abandoned cart"))
      end
    end
    
    context 'edge cases' do
      it 'does not remove cart abandoned less than 7 days ago' do
        less_than_7_days_cart = Cart.create(session_id: "less_than_7_days", total_price: 0, abandoned_at: 6.days.ago + 23.hours)
        less_than_7_days_cart.add_product(product, 1)
        
        expect {
          AbandonedCartJob.new.perform
        }.not_to change { Cart.count }
        
        expect(Cart.exists?(less_than_7_days_cart.id)).to be true
      end
      
      it 'removes cart abandoned more than 7 days ago' do
        just_over_7_days_cart = Cart.create(session_id: "just_over_7_days", total_price: 0, abandoned_at: 7.days.ago - 1.second)
        just_over_7_days_cart.add_product(product, 1)
        
        expect {
          AbandonedCartJob.new.perform
        }.to change { Cart.count }.by(-1)
        
        expect(Cart.exists?(just_over_7_days_cart.id)).to be false
      end
    end
  end
end