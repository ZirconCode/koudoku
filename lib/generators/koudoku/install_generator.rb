# this generator based on rails_admin's install generator.
# https://www.github.com/sferik/rails_admin/master/lib/generators/rails_admin/install_generator.rb

require 'rails/generators'

# http://guides.rubyonrails.org/generators.html
# http://rdoc.info/github/wycats/thor/master/Thor/Actions.html

module Koudoku
  class InstallGenerator < Rails::Generators::Base

    # Not sure what this does.
    source_root File.expand_path("../templates", __FILE__)

    include Rails::Generators::Migration

    argument :subscription_owner_model, :type => :string, :required => true, :desc => "Owner of the subscription"
    desc "Koudoku installation generator"

    def install
      
      unless defined?(Koudoku)
        gem("koudoku")
      end
      
      require "securerandom"
      api_key = SecureRandom.uuid
      create_file 'config/initializers/koudoku.rb' do
      <<-RUBY
Koudoku.setup do |config|
  config.webhooks_api_key = "#{api_key}"
end
RUBY
      end

      # Generate subscription.
      generate("model", "subscription stripe_id:string plan_id:integer last_four:string coupon_id:integer current_price:float #{subscription_owner_model}_id:integer")
      gsub_file "app/models/subscription.rb", /ActiveRecord::Base/, "ActiveRecord::Base\n  include Koudoku::Subscription\n\n  belongs_to :#{subscription_owner_model}\n  belongs_to :coupon\n"
      
      # Add the plans.
      generate("model", "plan name:string stripe_id:string price:float")
      gsub_file "app/models/plan.rb", /ActiveRecord::Base/, "ActiveRecord::Base\n  belongs_to :#{subscription_owner_model}\n  belongs_to :coupon\n"

      # Add coupons.
      generate("model coupon code:string free_trial_length:string")
      gsub_file "app/models/plan.rb", /ActiveRecord::Base/, "ActiveRecord::Base\n  has_many :subscriptions\n"
      
      # Update the owner relationship.
      gsub_file "app/models/#{subscription_owner_model}.rb", /ActiveRecord::Base/, "ActiveRecord::Base\n\n  # Added by Koudoku.\n  has_one :subscription\n\n"

      # Update the owner relationship.
      gsub_file "app/models/#{subscription_owner_model}.rb", /ActiveRecord::Base/, "ActiveRecord::Base\n\n  # Added by Koudoku.\n  has_one :subscription\n\n"

      # Add webhooks to the route.
      gsub_file "config/routes.rb", /Application.routes.draw do/, "Application.routes.draw do\n\n  # Added by Koudoku.\n  namespace :koudoku do\n    match 'webhooks' => 'webhooks#process'\n  end\n\n"
      
      # Show the user the API key we generated.
      say "\nTo enable support for Stripe webhooks, point it to \"/koudoku/webhooks?api_key=#{api_key}\". This API key has been randomly generated, so it's unique to your application.\n\n"
      
    end

  end
end