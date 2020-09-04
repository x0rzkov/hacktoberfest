# frozen_string_literal: true

# Sidekiq configuration
# See: https://github.com/mperham/sidekiq

# Redis config shared between client and server
# rubocop:disable Style/MutableConstant
if (redis = ENV.fetch('HACKTOBERFEST_REDIS_URL', nil))
  REDIS_CONFIG = {
    host: redis,
    port: ENV['HACKTOBERFEST_REDIS_PORT'] || '6379'
  }
elsif (redis_url = ENV.fetch('REDIS_HOST', nil))
  REDIS_LOCAL = { url:  "redis://#{redis_url}:#{ENV['REDIS_PORT']}/12" }
end

# rubocop:enable Style/MutableConstant

# Custom Error message reporting a job death to airbrake
module Sidekiq
  class JobDeathError < StandardError
    def initialize(job, exec)
      @job = job
      @ex = exec
    end

    def message
      "#{@job['class']} #{@job['jid']} died with error #{@ex.message}."
    end
  end
end

Sidekiq.configure_server do |config|
  config.redis = if defined?(REDIS_CONFIG)
                   REDIS_CONFIG
                 elsif defined?(REDIS_LOCAL)
                   REDIS_LOCAL
                 end

  config.death_handlers << lambda { |job, ex|
    error = Sidekiq::JobDeathError.new(job, ex)
    Airbrake.notify(error) do |notice|
      notice[:context][:component] = 'sidekiq'
    end
  }
end

Sidekiq.configure_client do |config|
  config.redis = if defined?(REDIS_CONFIG)
                   REDIS_CONFIG
                 elsif defined?(REDIS_LOCAL)
                   REDIS_LOCAL
                 end
end
