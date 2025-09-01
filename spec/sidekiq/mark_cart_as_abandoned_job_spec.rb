require 'rails_helper'

RSpec.describe MarkCartAsAbandonedJob, type: :job do
  let(:event_store) { Rails.configuration.event_store }
  let!(:product) { Product.create(name: "Test Product", price: 10.0) }
  let!(:cart) { Cart.create(session_id: "test_session", total_price: 20.0) }
  
  before do
    cart.add_product(product, 2)
  end

  describe '#perform' do
    context 'when cart exists and is not abandoned' do
      it 'marks the cart as abandoned' do
        expect {
          described_class.new.perform(cart.id)
        }.to change { cart.reload.abandoned? }.from(false).to(true)
      end

      it 'sets the abandoned_at timestamp' do
        before_time = Time.current
        described_class.new.perform(cart.id)
        after_time = Time.current
        
        expect(cart.reload.abandoned_at).to be_between(before_time, after_time)
      end

      it 'publishes CartAbandoned event' do
        expect(event_store).to receive(:publish).with(
          an_instance_of(CartAbandoned)
        )
        
        described_class.new.perform(cart.id)
      end

      it 'publishes event with correct data' do
        allow(event_store).to receive(:publish) do |event|
          expect(event.data[:cart_id]).to eq(cart.id)
          expect(event.data[:session_id]).to eq(cart.session_id)
          expect(event.data[:total_items]).to eq(2)
          expect(event.data[:total_value]).to eq(cart.total_price)
          expect(event.data[:last_interaction_at]).to be_within(1.second).of(cart.updated_at)
          expect(event.data[:abandoned_at]).to be_present
        end
        
        described_class.new.perform(cart.id)
      end

      it 'logs the abandonment' do
        expect(Rails.logger).to receive(:info).with("Carrinho #{cart.id} marcado como abandonado")
        described_class.new.perform(cart.id)
      end
    end

    context 'when cart does not exist' do
      it 'does not raise an error' do
        expect {
          described_class.new.perform(999999)
        }.not_to raise_error
      end

      it 'does not publish any event' do
        expect(event_store).not_to receive(:publish)
        described_class.new.perform(999999)
      end
    end

    context 'when cart is already abandoned' do
      before do
        cart.update!(abandoned_at: 1.hour.ago)
      end

      it 'does not change the cart' do
        original_abandoned_at = cart.abandoned_at
        
        described_class.new.perform(cart.id)
        
        expect(cart.reload.abandoned_at).to eq(original_abandoned_at)
      end

      it 'does not publish any event' do
        expect(event_store).not_to receive(:publish)
        described_class.new.perform(cart.id)
      end
    end
  end
end
