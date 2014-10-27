module BatchApi
  class RackMiddleware

    class << self
      def content_type
        { "Content-Type" => "application/json" }
      end

      def allow
        { "Allow" => BatchApi.config.verb.to_s.upcase }
      end

      def batch_endpoint?(env)
        case (endpoint = BatchApi.config.endpoint)
        when String then endpoint == env["PATH_INFO"]
        when Regexp then endpoint =~ env["PATH_INFO"]
        when Proc then endpoint.call(env)
        end
      end

      def batch_method?(env)
        env["REQUEST_METHOD"] == BatchApi.config.verb.to_s.upcase
      end

      def batch_request?(env)
        batch_endpoint?(env) && batch_method?(env)
      end
    end


    def initialize(app, &block)
      @app = app
      yield BatchApi.config if block
    end

    def call(env)
      case
      when batch_request?(env)
        begin
          request = request_klass.new(env)
          result = BatchApi::Processor.new(request, @app).execute!
          response = [200, self.class.content_type, [MultiJson.dump(result)]]
          filter = init_filter(env)
          filter.call(response)
        rescue => err
          ErrorWrapper.new(err).render
        end
      when batch_endpoint?(env) && options?(env)
        [204, self.class.content_type.merge(self.class.allow), ['']]
      else
        @app.call(env)
      end
    end


    private

    def batch_endpoint?(env) self.class.batch_endpoint?(env) end
    def batch_method?(env) self.class.batch_method?(env) end
    def batch_request?(env) self.class.batch_request?(env) end

    def options?(env)
      env["REQUEST_METHOD"] == 'OPTIONS'
    end

    def request_klass
      defined?(ActionDispatch) ? ActionDispatch::Request : Rack::Request
    end


    def init_filter(env)
      filter = BatchApi.config.rack_response_filter
      if filter.respond_to?(:new)
        filter = filter.new(env)
      end
      filter
    end

  end
end
