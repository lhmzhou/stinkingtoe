# frozen_string_literal: true

require 'socket'

module StinkingToe
  module Comment
    mattr_accessor :components, :lines_to_ignore, :prepend_comment
    StinkingToe::Comment.components ||= [:application, :controller, :action]

    def self.update!(controller = nil)
      self.stinkingtoe_controller = controller
    end

    def self.update_job!(job)
      self.stinkingtoe_job = job
    end

    def self.update_adapter!(adapter)
      self.stinkingtoe_adapter = adapter
    end

    def self.construct_comment
      ret = String.new
      self.components.each do |c|
        component_value = self.send(c)
        if component_value.present?
          ret << "#{c}:#{component_value},"
        end
      end
      ret.chop!
      ret = self.escape_sql_comment(ret)
      ret
    end

    def self.construct_inline_comment
      return nil if inline_annotations.none?
      escape_sql_comment(inline_annotations.join)
    end

    def self.escape_sql_comment(str)
      while str.include?('/*') || str.include?('*/')
        str = str.gsub('/*', '').gsub('*/', '')
      end
      str
    end

    def self.clear!
      self.stinkingtoe_controller = nil
    end

    def self.clear_job!
      self.stinkingtoe_job = nil
    end

    private
      def self.stinkingtoe_controller=(controller)
        Thread.current[:stinkingtoe_controller] = controller
      end

      def self.stinkingtoe_controller
        Thread.current[:stinkingtoe_controller]
      end

      def self.stinkingtoe_job=(job)
        Thread.current[:stinkingtoe_job] = job
      end

      def self.stinkingtoe_job
        Thread.current[:stinkingtoe_job]
      end

      def self.stinkingtoe_adapter=(adapter)
        Thread.current[:stinkingtoe_adapter] = adapter
      end

      def self.stinkingtoe_adapter
        Thread.current[:stinkingtoe_adapter]
      end

      def self.application
        if defined?(Rails.application)
          StinkingToe.application_name ||= Rails.application.class.name.split("::").first
        else
          StinkingToe.application_name ||= "rails"
        end

        StinkingToe.application_name
      end

      def self.job
        stinkingtoe_job.class.name if stinkingtoe_job
      end

      def self.controller
        stinkingtoe_controller.controller_name if stinkingtoe_controller.respond_to? :controller_name
      end

      def self.controller_with_namespace
        stinkingtoe_controller.class.name if stinkingtoe_controller
      end

      def self.action
        stinkingtoe_controller.action_name if stinkingtoe_controller.respond_to? :action_name
      end

      def self.sidekiq_job
        stinkingtoe_job["class"] if stinkingtoe_job && stinkingtoe_job.respond_to?(:[])
      end

      DEFAULT_LINES_TO_IGNORE_REGEX = %r{\.rvm|/ruby/gems/|vendor/|stinkingtoe|rbenv|monitor\.rb.*mon_synchronize}

      def self.line
        StinkingToe::Comment.lines_to_ignore ||= DEFAULT_LINES_TO_IGNORE_REGEX

        last_line = caller_locations.detect do |loc|
          !loc.path.match?(StinkingToe::Comment.lines_to_ignore)
        end
        if last_line
          last_line = last_line.to_s

          root = if defined?(Rails) && Rails.respond_to?(:root)
            Rails.root.to_s
          elsif defined?(RAILS_ROOT)
            RAILS_ROOT
          else
            ""
          end
          if last_line.start_with? root
            last_line = last_line[root.length..-1]
          end
          last_line
        end
      end

      def self.hostname
        @cached_hostname ||= Socket.gethostname
      end

      def self.pid
        Process.pid
      end

      def self.request_id
        if stinkingtoe_controller.respond_to?(:request) && stinkingtoe_controller.request.respond_to?(:uuid)
          stinkingtoe_controller.request.uuid
        end
      end

      def self.socket
        if self.connection_config.present?
          self.connection_config[:socket]
        end
      end

      def self.db_host
        if self.connection_config.present?
          self.connection_config[:host]
        end
      end

      def self.database
        if self.connection_config.present?
          self.connection_config[:database]
        end
      end

      if Gem::Version.new(ActiveRecord::VERSION::STRING) < Gem::Version.new('6.1')
        def self.connection_config
          return if stinkingtoe_adapter.pool.nil?
          stinkingtoe_adapter.pool.spec.config
        end
      else
        def self.connection_config
          # `pool` might be a NullPool which has no db_config
          return unless stinkingtoe_adapter.pool.respond_to?(:db_config)
          stinkingtoe_adapter.pool.db_config.configuration_hash
        end
      end

      def self.inline_annotations
        Thread.current[:stinkingtoe_inline_annotations] ||= []
      end
  end

end
