require 'stinkingtoe/railtie'
require 'stinkingtoe/comment'
require 'stinkingtoe/sidekiq_instrumentation'

module StinkingToe
  mattr_accessor :application_name

  module ActiveRecordInstrumentation
    def self.included(instrumented_class)
      instrumented_class.class_eval do
        if instrumented_class.method_defined?(:execute)
          alias_method :execute_without_stinkingtoe, :execute
          alias_method :execute, :execute_with_stinkingtoe
        end

        if instrumented_class.private_method_defined?(:execute_and_clear)
          alias_method :execute_and_clear_without_stinkingtoe, :execute_and_clear
          alias_method :execute_and_clear, :execute_and_clear_with_stinkingtoe
        else
          is_mysql2 = defined?(ActiveRecord::ConnectionAdapters::Mysql2Adapter) &&
            ActiveRecord::ConnectionAdapters::Mysql2Adapter == instrumented_class
          # Dont instrument exec_query on mysql2 as it calls execute internally
          unless is_mysql2
            if instrumented_class.method_defined?(:exec_query)
              alias_method :exec_query_without_stinkingtoe, :exec_query
              alias_method :exec_query, :exec_query_with_stinkingtoe
            end
          end

          is_postgres = defined?(ActiveRecord::ConnectionAdapters::PostgreSQLAdapter) &&
            ActiveRecord::ConnectionAdapters::PostgreSQLAdapter == instrumented_class
          # Instrument exec_delete and exec_update since they don't call
          # execute internally
          if is_postgres
            if instrumented_class.method_defined?(:exec_delete)
              alias_method :exec_delete_without_stinkingtoe, :exec_delete
              alias_method :exec_delete, :exec_delete_with_stinkingtoe
            end
            if instrumented_class.method_defined?(:exec_update)
              alias_method :exec_update_without_stinkingtoe, :exec_update
              alias_method :exec_update, :exec_update_with_stinkingtoe
            end
          end
        end
      end
    end

    def annotate_sql(sql)
      StinkingToe::Comment.update_adapter!(self)
      comment = StinkingToe::Comment.construct_comment
      if comment.present? && !sql.include?(comment)
        sql = if StinkingToe::Comment.prepend_comment
          "/*#{comment}*/ #{sql}"
        else
          "#{sql} /*#{comment}*/"
        end
      end
      inline_comment = StinkingToe::Comment.construct_inline_comment
      if inline_comment.present? && !sql.include?(inline_comment)
        sql = if StinkingToe::Comment.prepend_comment
          "/*#{inline_comment}*/ #{sql}"
        else
          "#{sql} /*#{inline_comment}*/"
        end
      end

      sql
    end

    def execute_with_stinkingtoe(sql, *args)
      execute_without_stinkingtoe(annotate_sql(sql), *args)
    end
    ruby2_keywords :execute_with_stinkingtoe if respond_to?(:ruby2_keywords, true)

    def exec_query_with_stinkingtoe(sql, *args, **options)
      options[:prepare] ||= false
      exec_query_without_stinkingtoe(annotate_sql(sql), *args, **options)
    end

    def exec_delete_with_stinkingtoe(sql, *args)
      exec_delete_without_stinkingtoe(annotate_sql(sql), *args)
    end
    ruby2_keywords :exec_delete_with_stinkingtoe if respond_to?(:ruby2_keywords, true)

    def exec_update_with_stinkingtoe(sql, *args)
      exec_update_without_stinkingtoe(annotate_sql(sql), *args)
    end
    ruby2_keywords :exec_update_with_stinkingtoe if respond_to?(:ruby2_keywords, true)

    def execute_and_clear_with_stinkingtoe(sql, *args, &block)
      execute_and_clear_without_stinkingtoe(annotate_sql(sql), *args, &block)
    end
    ruby2_keywords :execute_and_clear_with_stinkingtoe if respond_to?(:ruby2_keywords, true)
  end

  module ActionControllerInstrumentation
    def self.included(instrumented_class)
      instrumented_class.class_eval do
        if respond_to?(:around_action)
          around_action :record_query_comment
        else
          around_filter :record_query_comment
        end
      end
    end

    def record_query_comment
      StinkingToe::Comment.update!(self)
      yield
    ensure
      StinkingToe::Comment.clear!
    end
  end

  def self.with_annotation(comment, &block)
    StinkingToe::Comment.inline_annotations.push(comment)
    block.call if block.present?
  ensure
    StinkingToe::Comment.inline_annotations.pop
  end
end
