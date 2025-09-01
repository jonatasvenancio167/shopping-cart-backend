Rails.application.configure do
  config.event_store = RailsEventStore::Client.new
end

Rails.configuration.to_prepare do
  Rails.configuration.event_store = RailsEventStore::Client.new
  
  event_store = Rails.configuration.event_store
  
  analytics_handler = AnalyticsHandler.new
  event_store.subscribe(analytics_handler, to: [CartCreated, ItemAddedToCart, ItemRemovedFromCart])
  
  notification_handler = NotificationHandler.new
  event_store.subscribe(notification_handler, to: [ItemAddedToCart])
  
  inventory_handler = InventoryHandler.new
  event_store.subscribe(inventory_handler, to: [ItemAddedToCart, ItemRemovedFromCart])
  
  cart_expiration_handler = CartExpirationHandler.new
  event_store.subscribe(cart_expiration_handler, to: [CartCreated, ItemAddedToCart, ItemRemovedFromCart])
end