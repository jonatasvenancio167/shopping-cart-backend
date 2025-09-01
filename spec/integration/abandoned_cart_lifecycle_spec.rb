require 'rails_helper'

RSpec.describe 'Abandoned Cart Lifecycle Integration', type: :integration do
  let!(:product1) { Product.create(name: "Product 1", price: 10.0) }
  let!(:product2) { Product.create(name: "Product 2", price: 20.0) }
  
  describe 'complete cart abandonment and cleanup lifecycle' do
    it 'follows the complete lifecycle from active cart to removal' do
      cart = Cart.create(session_id: "integration_test_session", total_price: 0)
      cart.add_product(product1, 2)
      cart.add_product(product2, 1)
      
      expect(cart.abandoned?).to be false
      expect(cart.cart_items.count).to eq(2)
      expect(cart.total_price.to_f).to eq(40.0) # (10 * 2) + (20 * 1)
      
      cart.update_column(:last_interaction_at, 4.hours.ago)
      
      expect {
        AbandonedCartJob.new.perform
      }.to change { cart.reload.abandoned? }.from(false).to(true)
      
      expect(cart.abandoned_at).to be_present
      expect(cart.abandoned_at).to be_within(1.minute).of(Time.current)
      
      expect(Cart.exists?(cart.id)).to be true
      expect(cart.cart_items.count).to eq(2)
      
      cart.update_column(:abandoned_at, 8.days.ago)
      
      expect {
        AbandonedCartJob.new.perform
      }.to change { Cart.exists?(cart.id) }.from(true).to(false)
      
      expect(CartItem.where(cart_id: cart.id)).to be_empty
    end
    
    it 'handles multiple carts at different lifecycle stages simultaneously' do
      active_cart = Cart.create(session_id: "active", total_price: 0)
      active_cart.add_product(product1, 1)
      active_cart.update_column(:last_interaction_at, 1.hour.ago)
      
      to_abandon_cart = Cart.create(session_id: "to_abandon", total_price: 0)
      to_abandon_cart.add_product(product1, 2)
      to_abandon_cart.update_column(:last_interaction_at, 4.hours.ago)
      
      recently_abandoned_cart = Cart.create(session_id: "recently_abandoned", total_price: 0, abandoned_at: 2.days.ago)
      recently_abandoned_cart.add_product(product2, 1)
      
      to_remove_cart = Cart.create(session_id: "to_remove", total_price: 0, abandoned_at: 8.days.ago)
      to_remove_cart.add_product(product1, 3)
      
      initial_cart_count = Cart.count
      initial_item_count = CartItem.count
      
      AbandonedCartJob.new.perform
      
      expect(active_cart.reload.abandoned?).to be false
      expect(to_abandon_cart.reload.abandoned?).to be true
      expect(Cart.exists?(recently_abandoned_cart.id)).to be true
      expect(Cart.exists?(to_remove_cart.id)).to be false
      
      expect(Cart.count).to eq(initial_cart_count - 1)
      expect(CartItem.count).to eq(initial_item_count - 3)
    end
  end
  
  describe 'edge cases and error scenarios' do
    it 'handles carts with no items gracefully' do
      empty_old_cart = Cart.create(session_id: "empty_old", total_price: 0)
      empty_old_cart.update_column(:last_interaction_at, 4.hours.ago)
      
      empty_abandoned_cart = Cart.create(session_id: "empty_abandoned", total_price: 0, abandoned_at: 8.days.ago)
      
      expect {
        AbandonedCartJob.new.perform
      }.to change { empty_old_cart.reload.abandoned? }.from(false).to(true)
       .and change { Cart.exists?(empty_abandoned_cart.id) }.from(true).to(false)
    end
    
    it 'handles concurrent modifications during cleanup' do
      cart = Cart.create(session_id: "concurrent_test", total_price: 0)
      cart.add_product(product1, 1)
      cart.update_column(:last_interaction_at, 4.hours.ago)
      
      allow(cart).to receive(:mark_as_abandoned!).and_wrap_original do |method|
        cart.add_product(product2, 1)
        method.call
      end
      
      allow(Cart).to receive_message_chain(:active, :old_interactions, :find_each).and_yield(cart)
      
      expect {
        AbandonedCartJob.new.perform
      }.not_to raise_error
    end
    
    it 'maintains data integrity during bulk operations' do
      carts_to_abandon = []
      carts_to_remove = []
      
      5.times do |i|
        cart = Cart.create(session_id: "bulk_abandon_#{i}", total_price: 0)
        cart.add_product(product1, i + 1)
        cart.update_column(:last_interaction_at, 4.hours.ago)
        carts_to_abandon << cart
      end
      
      3.times do |i|
        cart = Cart.create(session_id: "bulk_remove_#{i}", total_price: 0, abandoned_at: 8.days.ago)
        cart.add_product(product2, i + 1)
        carts_to_remove << cart
      end
      
      initial_cart_count = Cart.count
      initial_item_count = CartItem.count
      
      AbandonedCartJob.new.perform
      
      carts_to_abandon.each do |cart|
        expect(cart.reload.abandoned?).to be true
      end
      
      carts_to_remove.each do |cart|
        expect(Cart.exists?(cart.id)).to be false
      end
      
      expect(Cart.count).to eq(initial_cart_count - 3)
      removed_items_count = 1 + 2 + 3 
      expect(CartItem.count).to eq(initial_item_count - removed_items_count)
    end
  end
  
  describe 'performance and logging' do
    it 'logs all operations correctly during full lifecycle' do
      cart = Cart.create(session_id: "logging_test", total_price: 0)
      cart.add_product(product1, 1)
      cart.update_column(:last_interaction_at, 4.hours.ago)
      
      old_abandoned_cart = Cart.create(session_id: "old_logging_test", total_price: 0, abandoned_at: 8.days.ago)
      old_abandoned_cart.add_product(product2, 1)
      
      allow(Rails.logger).to receive(:info)
      
      AbandonedCartJob.new.perform
      
      expect(Rails.logger).to have_received(:info).with("Cart #{cart.id} marked as abandoned")
      expect(Rails.logger).to have_received(:info).with("Removing abandoned cart #{old_abandoned_cart.id}")
      expect(Rails.logger).to have_received(:info).with("Abandoned cart cleanup completed")
    end
    
    it 'completes cleanup efficiently with large datasets' do
      start_time = Time.current
      
      10.times do |i|
        cart = Cart.create(session_id: "perf_test_#{i}", total_price: 0)
        cart.add_product(product1, 1)
        cart.update_column(:last_interaction_at, 4.hours.ago)
      end
      
      5.times do |i|
        cart = Cart.create(session_id: "perf_remove_#{i}", total_price: 0, abandoned_at: 8.days.ago)
        cart.add_product(product2, 1)
      end
      
      expect {
        AbandonedCartJob.new.perform
      }.to change { Cart.abandoned.count }.by(10)
       .and change { Cart.count }.by(-5)
      
      execution_time = Time.current - start_time
      expect(execution_time).to be < 5.seconds 
    end
  end
end