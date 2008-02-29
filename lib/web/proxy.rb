module Cheese
  module Nginx
    #
    # Represents the proxies to external processes that a vhost requires
    #
    class Proxy
      attr_reader :domain, :ports, :config
  
      DELEGATED_METHODS = [:remove]
      
      def initialize(domain, ports, config)
        @domain, @ports = domain, ports.to_a
        @config = config
      end
      
      def method_missing(meth, *args, &block)
        if DELEGATED_METHODS.include? meth
          @config.send(meth, self)
        end
      end
    end
  end
end