class CartCreated < RubyEventStore::Event
  SCHEMA = {
    cart_id: Integer,
    session_id: String,
    created_at: Time
  }.freeze

  def self.strict(data:)
    new(data: data)
  end
end