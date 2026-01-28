module StinkingToe

  # Alternative to ActiveJob Instrumentation for Sidekiq.
  module SidekiqInstrumentation

    class Middleware
      def call(worker, msg, queue)
        StinkingToe::Comment.update_job! msg
        yield
      ensure
        StinkingToe::Comment.clear_job!
      end
    end

    def self.enable!
      Sidekiq.configure_server do |config|
        config.server_middleware do |chain|
          chain.add StinkingToe::SidekiqInstrumentation::Middleware
        end
      end
    end
  end

end
