class CartExpirationHandler
  def call(event)
    case event
    when CartCreated, ItemAddedToCart, ItemRemovedFromCart
      cancel_existing_expiration_job(event.data[:cart_id])
      
      MarkCartAsAbandonedJob.perform_in(3.hours, event.data[:cart_id])
      
      Rails.logger.info "Agendado job de expiração para carrinho #{event.data[:cart_id]}"
    end
  end

  private

  def cancel_existing_expiration_job(cart_id)
    Sidekiq::ScheduledSet.new.each do |job|
      if job.klass == 'MarkCartAsAbandonedJob' && job.args.first == cart_id
        job.delete
        Rails.logger.info "Cancelado job de expiração anterior para carrinho #{cart_id}"
      end
    end
  end
end