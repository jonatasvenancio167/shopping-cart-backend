class Cart < ApplicationRecord
  has_many :cart_items, dependent: :destroy
  has_many :products, through: :cart_items

  validates :total_price, presence: true, numericality: { greater_than_or_equal_to: 0 }
  validates :session_id, presence: true

  before_validation :generate_session_id, on: :create
  before_save :calculate_total_price
  before_save :update_last_interaction

  scope :abandoned, -> { where.not(abandoned_at: nil) }
  scope :active, -> { where(abandoned_at: nil) }
  scope :old_interactions, ->(time_ago) { where('last_interaction_at < ?', time_ago) }

  def add_product(product, quantity = 1)
    cart_item = cart_items.find_by(product: product)
    
    if cart_item
      cart_item.quantity += quantity
      cart_item.save!
    else
      cart_items.create!(product: product, quantity: quantity)
    end
    
    reload
    calculate_total_price
    save!
  end

  def remove_product(product)
    cart_items.find_by(product: product)&.destroy
    reload
    calculate_total_price
    save!
  end

  def update_product_quantity(product, quantity)
    cart_item = cart_items.find_by(product: product)
    return false unless cart_item
    
    if quantity <= 0
      cart_item.destroy
    else
      cart_item.update!(quantity: quantity)
    end
    
    reload
    calculate_total_price
    save!
    true
  end

  def mark_as_abandoned!
    update!(abandoned_at: Time.current)
  end

  def remove_if_abandoned!
    destroy if abandoned_at.present?
  end

  def abandoned?
    abandoned_at.present?
  end



  def products_list
    cart_items.includes(:product).map do |item|
      {
        id: item.product.id,
        name: item.product.name,
        quantity: item.quantity,
        unit_price: item.product.price,
        total_price: item.total_price
      }
    end
  end

  private

  def generate_session_id
    self.session_id ||= SecureRandom.uuid
  end

  def calculate_total_price
    self.total_price = cart_items.joins(:product).sum('cart_items.quantity * products.price')
  end

  def update_last_interaction
    self.last_interaction_at = Time.current
  end
end
