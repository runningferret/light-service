module LightService
  module Organizer
    class WithReducerLogDecorator
      attr_reader :logged, :logger, :decorated, :organizer

      alias logged? logged

      def initialize(organizer, decorated = WithReducer.new)
        @decorated = decorated
        @organizer = organizer
        @logger = LightService::Configuration.logger
        @logged = false
      end

      def with(data = {})
        logger.info("[LightService] - calling organizer <#{organizer}>")

        decorated.with(data)

        logger.info("[LightService] -     keys in context: " \
                    "#{extract_keys(decorated.context.keys)}")
        self
      end

      def around_each(handler)
        decorated.around_each(handler)
        self
      end

      def reduce(*actions)
        decorated.reduce(*actions) do |context, action|
          next context if logged?

          if has_failure?(context)
            write_failure_log(context, action)
            next context
          end

          if skip_all?(context)
            write_skip_all_log(context, action)
            next context
          end

          write_log(action, context)
        end
      end

      private

      def write_log(action, context)
        logger.info("[LightService] - executing <#{action}>")
        log_expects(action)
        log_promises(action)
        logger.info("[LightService] -     keys in context: "\
                    "#{extract_keys(context.keys)}")
      end

      def log_expects(action)
        if defined?(action.expects) && action.expects.any?
          logger.info("[LightService] -   expects: " \
                      "#{extract_keys(action.expects)}")
        end
      end

      def log_promises(action)
        if defined?(action.promises) && action.promises.any?
          logger.info("[LightService] -   promises: " \
                      "#{extract_keys(action.promises)}")
        end
      end

      def extract_keys(keys)
        keys.map { |key| ":#{key}" }.join(', ')
      end

      def has_failure?(context)
        context.respond_to?(:failure?) && context.failure?
      end

      def write_failure_log(context, action)
        logger.warn("[LightService] - :-((( <#{action}> has failed...")
        logger.warn("[LightService] - context message: #{context.message}")
        @logged = true
      end

      def skip_all?(context)
        context.respond_to?(:skip_all?) && context.skip_all?
      end

      def write_skip_all_log(context, action)
        msg = "[LightService] - ;-) <#{action}> has decided " \
              "to skip the rest of the actions"
        logger.info(msg)
        logger.info("[LightService] - context message: #{context.message}")
        @logged = true
      end
    end
  end
end
