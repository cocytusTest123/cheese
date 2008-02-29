module Cheese
  module Nginx
    #
    # Represents an nginx domain, which encompasses the vhost and proxies
    #
    class Domain
      attr_reader :vhost, :proxy, :host
    
      def initialize(vhost, proxy)
        @vhost, @proxy = vhost, proxy
        @host = @vhost.domain
      end
      
      def remove
        @vhost.remove
        @proxy.remove
      end
    end
  end
end