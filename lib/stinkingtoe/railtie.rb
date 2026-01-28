require 'stinkingtoe'
require 'rails/railtie'

module StinkingToe
  class Railtie < Rails::Railtie
    initializer 'marginalia.insert' do
      ActiveSupport.on_load :active_record do
        StinkingToe::Railtie.insert_into_active_record
      end

      ActiveSupport.on_load :action_controller do
        StinkingToe::Railtie.insert_into_action_controller
      end

      ActiveSupport.on_load :active_job do
        StinkingToe::Railtie.insert_into_active_job
      end
    end

    def self.insert
      insert_into_active_record
      insert_into_action_controller
      insert_into_active_job
    end

    def self.insert_into_active_job
      if defined? ActiveJob::Base
        ActiveJob::Base.class_eval do
          around_perform do |job, block|
            begin
              StinkingToe::Comment.update_job! job
              block.call
            ensure
              StinkingToe::Comment.clear_job!
            end
          end
        end
      end
    end

    def self.insert_into_action_controller
      ActionController::Base.send(:include, ActionControllerInstrumentation)
      if defined? ActionController::API
        ActionController::API.send(:include, ActionControllerInstrumentation)
      end
    end

    def self.insert_into_active_record
      if defined? ActiveRecord::ConnectionAdapters::Mysql2Adapter
        ActiveRecord::ConnectionAdapters::Mysql2Adapter.module_eval do
          include StinkingToe::ActiveRecordInstrumentation
        end
      end

      if defined? ActiveRecord::ConnectionAdapters::MysqlAdapter
        ActiveRecord::ConnectionAdapters::MysqlAdapter.module_eval do
          include StinkingToe::ActiveRecordInstrumentation
        end
      end

      if defined? ActiveRecord::ConnectionAdapters::PostgreSQLAdapter
        ActiveRecord::ConnectionAdapters::PostgreSQLAdapter.module_eval do
          include StinkingToe::ActiveRecordInstrumentation
        end
      end

      if defined? ActiveRecord::ConnectionAdapters::SQLite3Adapter
        ActiveRecord::ConnectionAdapters::SQLite3Adapter.module_eval do
          include StinkingToe::ActiveRecordInstrumentation
        end
      end
    end
  end
end
