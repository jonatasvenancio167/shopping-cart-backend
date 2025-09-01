class ItemAddedToCart < RubyEventStore::Event
  SCHEMA = {
    cart_id: Integer,
    product_id: Integer,
    quantity: Integer,
    product_name: String,
    product_price: Float,
    session_id: String,
    added_at: Time
  }.freeze

  def self.strict(data:)
    new(data: data)
  end
end