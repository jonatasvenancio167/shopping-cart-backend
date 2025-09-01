class MarkCartAsAbandonedJob
  include Sidekiq::Job

  def perform(cart_id)
    cart = Cart.find_by(id: cart_id)
    return unless cart && !cart.abandoned?

    cart.update!(
      abandoned_at: Time.current
    )

    event_store.publish(
      CartAbandoned.new(data: {
        cart_id: cart.id,
        session_id: cart.session_id,
        total_items: cart.cart_items.sum(:quantity),
        total_value: cart.total_price,
        last_interaction_at: cart.updated_at,
        abandoned_at: cart.abandoned_at
      })
    )

    Rails.logger.info "Carrinho #{cart_id} marcado como abandonado"
  end

  private

  def event_store
    Rails.configuration.event_store
  end
end
