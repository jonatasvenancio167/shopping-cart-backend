class CartAbandoned < RubyEventStore::Event
  SCHEMA = {
    cart_id: Integer,
    session_id: String,
    total_items: Integer,
    total_value: Float,
    last_interaction_at: Time,
    abandoned_at: Time
  }.freeze

  def self.strict(data:)
    new(data: data)
  end
end