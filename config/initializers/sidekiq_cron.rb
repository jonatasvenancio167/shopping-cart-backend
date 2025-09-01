require 'sidekiq-cron'

Sidekiq::Cron::Job.load_from_hash({
  'abandoned_cart_cleanup' => {
    'cron' => '0 * * * *', 
    'class' => 'AbandonedCartJob'
  }
})