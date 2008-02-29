module Cheese
  module Nginx
    #
    # Represents a vhost in an nginx config file
    #
    class VirtualHost
      attr_reader :domain, :config
  
      DELEGATED_METHODS = [:remove]
  
      def initialize(domain, config)
        @domain, @config = domain, config
      end
  
      def method_missing(meth, *args, &block)
        if DELEGATED_METHODS.include? meth
          @config.send(meth, self)
        end
      end
    end
  end
end