require 'rails_helper'

RSpec.describe AbandonedCartJob, type: :job do
  let!(:product) { Product.create(name: "Test Product", price: 10.0) }
  
  describe '#perform' do
    context 'marking carts as abandoned after 3 hours' do
      let!(:recent_cart) { Cart.create(session_id: "recent_session", total_price: 0) }
      let!(:old_cart) { Cart.create(session_id: "old_session", total_price: 0) }
      let!(:very_old_cart) { Cart.create(session_id: "very_old_session", total_price: 0) }
      
      before do
        recent_cart.add_product(product, 1)
        old_cart.add_product(product, 2)
        very_old_cart.add_product(product, 3)
        
        recent_cart.update_column(:last_interaction_at, 2.hours.ago)
        old_cart.update_column(:last_interaction_at, 4.hours.ago)
        very_old_cart.update_column(:last_interaction_at, 5.hours.ago)
      end
      
      it 'marks carts with last interaction older than 3 hours as abandoned' do
        expect {
          described_class.new.perform
        }.to change { old_cart.reload.abandoned? }.from(false).to(true)
         .and change { very_old_cart.reload.abandoned? }.from(false).to(true)
      end
      
      it 'does not mark recent carts as abandoned' do
        described_class.new.perform
        expect(recent_cart.reload.abandoned?).to be_falsey
      end
      
      it 'sets abandoned_at timestamp for old carts' do
        before_time = Time.current
        described_class.new.perform
        after_time = Time.current
        
        expect(old_cart.reload.abandoned_at).to be_between(before_time, after_time)
        expect(very_old_cart.reload.abandoned_at).to be_between(before_time, after_time)
      end
      
      it 'logs the abandonment of each cart' do
        allow(Rails.logger).to receive(:info)
        
        described_class.new.perform
        
        expect(Rails.logger).to have_received(:info).with("Cart #{old_cart.id} marked as abandoned")
        expect(Rails.logger).to have_received(:info).with("Cart #{very_old_cart.id} marked as abandoned")
        expect(Rails.logger).to have_received(:info).with("Abandoned cart cleanup completed")
      end
    end
    
    context 'removing carts abandoned for more than 7 days' do
      let!(:recently_abandoned_cart) { Cart.create(session_id: "recent_abandoned", total_price: 0, abandoned_at: 5.days.ago) }
      let!(:old_abandoned_cart) { Cart.create(session_id: "old_abandoned", total_price: 0, abandoned_at: 8.days.ago) }
      let!(:very_old_abandoned_cart) { Cart.create(session_id: "very_old_abandoned", total_price: 0, abandoned_at: 10.days.ago) }
      
      before do
        recently_abandoned_cart.add_product(product, 1)
        old_abandoned_cart.add_product(product, 2)
        very_old_abandoned_cart.add_product(product, 3)
      end
      
      it 'removes carts abandoned for more than 7 days' do
        expect {
          described_class.new.perform
        }.to change { Cart.count }.by(-2)
        
        expect(Cart.exists?(old_abandoned_cart.id)).to be_falsey
        expect(Cart.exists?(very_old_abandoned_cart.id)).to be_falsey
      end
      
      it 'does not remove recently abandoned carts' do
        described_class.new.perform
        expect(Cart.exists?(recently_abandoned_cart.id)).to be_truthy
      end
      
      it 'logs the removal of each old abandoned cart' do
        allow(Rails.logger).to receive(:info)
        
        described_class.new.perform
        
        expect(Rails.logger).to have_received(:info).with("Removing abandoned cart #{old_abandoned_cart.id}")
        expect(Rails.logger).to have_received(:info).with("Removing abandoned cart #{very_old_abandoned_cart.id}")
        expect(Rails.logger).to have_received(:info).with("Abandoned cart cleanup completed")
      end
    end
    
    context 'mixed scenario with both marking and removing' do
      let!(:active_cart) { Cart.create(session_id: "active", total_price: 0) }
      let!(:to_abandon_cart) { Cart.create(session_id: "to_abandon", total_price: 0) }
      let!(:recently_abandoned_cart) { Cart.create(session_id: "recent_abandoned", total_price: 0, abandoned_at: 3.days.ago) }
      let!(:to_remove_cart) { Cart.create(session_id: "to_remove", total_price: 0, abandoned_at: 8.days.ago) }
      
      before do
        active_cart.add_product(product, 1)
        to_abandon_cart.add_product(product, 2)
        recently_abandoned_cart.add_product(product, 3)
        to_remove_cart.add_product(product, 4)
        
        active_cart.update_column(:last_interaction_at, 1.hour.ago)
        to_abandon_cart.update_column(:last_interaction_at, 4.hours.ago)
      end
      
      it 'performs both operations correctly' do
        expect {
          described_class.new.perform
        }.to change { to_abandon_cart.reload.abandoned? }.from(false).to(true)
         .and change { Cart.count }.by(-1)
        
        expect(active_cart.reload.abandoned?).to be_falsey
        
        expect(Cart.exists?(recently_abandoned_cart.id)).to be_truthy
        
        expect(Cart.exists?(to_remove_cart.id)).to be_falsey
      end
      
      it 'logs completion message' do
        allow(Rails.logger).to receive(:info)
        
        described_class.new.perform
        
        expect(Rails.logger).to have_received(:info).with("Abandoned cart cleanup completed")
      end
    end
    
    context 'when no carts need processing' do
      let!(:active_cart) { Cart.create(session_id: "active", total_price: 0, last_interaction_at: 1.hour.ago) }
      let!(:recently_abandoned_cart) { Cart.create(session_id: "recent_abandoned", total_price: 0, abandoned_at: 3.days.ago) }
      
      it 'does not change any carts' do
        expect {
          described_class.new.perform
        }.not_to change { Cart.count }
        
        expect(active_cart.reload.abandoned?).to be_falsey
        expect(recently_abandoned_cart.reload.abandoned?).to be_truthy
      end
      
      it 'still logs completion' do
        allow(Rails.logger).to receive(:info)
        
        described_class.new.perform
        
        expect(Rails.logger).to have_received(:info).with("Abandoned cart cleanup completed")
      end
    end
  end
end