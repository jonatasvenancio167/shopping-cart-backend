require 'rails_helper'
require 'sidekiq-cron'

RSpec.describe 'Abandoned Cart Cron Configuration', type: :job do
  describe 'cron job configuration' do
    it 'has the abandoned_cart_cleanup job configured' do
      job = Sidekiq::Cron::Job.find('abandoned_cart_cleanup')
      expect(job).not_to be_nil
    end
    
    it 'is configured to run every hour' do
      job = Sidekiq::Cron::Job.find('abandoned_cart_cleanup')
      expect(job.cron).to eq('0 * * * *')
    end
    
    it 'is configured to use the AbandonedCartJob class' do
      job = Sidekiq::Cron::Job.find('abandoned_cart_cleanup')
      expect(job.klass).to eq('AbandonedCartJob')
    end
    
    it 'can be enqueued manually' do
      job = Sidekiq::Cron::Job.find('abandoned_cart_cleanup')
      expect(job.enque!).to be_truthy
    end
  end
  
  describe 'job scheduling behavior' do
    let!(:product) { Product.create(name: "Test Product", price: 10.0) }
    
    before do
      # Clear any existing jobs
      Sidekiq::Queue.new.clear
      Sidekiq::RetrySet.new.clear
      Sidekiq::DeadSet.new.clear
    end
    
    it 'enqueues the job when triggered by cron' do
      job = Sidekiq::Cron::Job.find('abandoned_cart_cleanup')
      
      expect {
        job.enque!
      }.to change { Sidekiq::Queue.new.size }.by(1)
    end
    
    it 'processes the job correctly when enqueued' do
      # Create test data
      old_cart = Cart.create(session_id: "old_session", total_price: 0)
      old_cart.add_product(product, 1)
      old_cart.update_column(:last_interaction_at, 4.hours.ago)
      
      old_abandoned_cart = Cart.create(session_id: "old_abandoned", total_price: 0, abandoned_at: 8.days.ago)
      old_abandoned_cart.add_product(product, 1)
      
      expect {
        AbandonedCartJob.new.perform
      }.to change { old_cart.reload.abandoned? }.from(false).to(true)
       .and change { Cart.exists?(old_abandoned_cart.id) }.from(true).to(false)
    end
  end
  
  describe 'cron expression validation' do
    it 'has a valid cron expression' do
      job = Sidekiq::Cron::Job.find('abandoned_cart_cleanup')
      cron_expression = job.cron
      
      expect { Fugit.parse(cron_expression) }.not_to raise_error
    end
    
    it 'runs at the top of every hour' do
      job = Sidekiq::Cron::Job.find('abandoned_cart_cleanup')
      cron = Fugit.parse(job.cron)
      
      base_time = Time.parse('2024-01-01 10:30:00')
      next_run = cron.next_time(base_time)
      
      expect(next_run.min).to eq(0)
      expect(next_run.hour).to eq(11)
    end
  end
  
  describe 'job reliability' do
    it 'can handle job failures gracefully' do
      allow_any_instance_of(AbandonedCartJob).to receive(:perform).and_raise(StandardError, "Test error")
      
      job = Sidekiq::Cron::Job.find('abandoned_cart_cleanup')
      expect {
        job.enque!
      }.not_to raise_error
      
      expect(Sidekiq::Queue.new.size).to be > 0
    end
    
    it 'maintains job configuration after restart' do
      Sidekiq::Cron::Job.destroy_all!
      
      load Rails.root.join('config/initializers/sidekiq_cron.rb')
      
      job = Sidekiq::Cron::Job.find('abandoned_cart_cleanup')
      expect(job).not_to be_nil
      expect(job.cron).to eq('0 * * * *')
      expect(job.klass).to eq('AbandonedCartJob')
    end
  end
end