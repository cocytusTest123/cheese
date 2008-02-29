# nginx.rb
#
# Acts as the proxy to an nginx conf file
#

module Cheese
  module Nginx
    
    # Represents the Nginx config file, giving the ability to manipulate
    # the VHosts within it, and save changes.
    class Config
      attr_reader :filename
      attr_accessor :domains

      # The values will be replaced in load_templates
      TEMPLATES = {
        :header => "header.inc",
        :footer => "footer.inc",
        :vhost  => "vhost.inc",
        :proxy  => "proxy.inc"
      }
      
      VHOST_BEGIN     = /#### VHOST (.*?) BEGIN ####/
      VHOST_END       = /#### VHOST (.*?) END ####/
      PROXY_BEGIN     = /#### PROXY (.*?) BEGIN ####/
      PROXY_END       = /#### PROXY (.*?) END ####/
      PROXY_THREAD    = /:(\d.*);/
    
    
      def initialize(file)
        @filename = file
        load_templates
        find_domains
      end
      
      # Find a domain which matches the url given
      def domain(url)
        @domains.detect {|domain| domain.vhost.domain == url}
      end
      
      # Add a virtual host to the Nginx config file
      def add(options={})
        domain = options[:name]
        return false if domain.nil?
        domain = clean_domain(domain)
        threads = options[:thread_count].to_i

        vhost_proxy = Cheese::Nginx::Proxy.new(domain, new_ports(threads), self)
        vhost = Cheese::Nginx::VirtualHost.new(domain, self)
        
        new_domain = Cheese::Nginx::Domain.new(vhost, vhost_proxy)
        @domains << new_domain
        return new_domain
      end
      
      # Remove a virtual host from the Nginx config file
      def remove(object)
        if object.is_a? Cheese::Nginx::VirtualHost
          @vhosts.delete(object) 
        elsif object.is_a? Cheese::Nginx::Proxy
          @proxies.delete(object)
        elsif object.is_a? Cheese::Nginx::Domain
          @domains.delete(object)
        elsif object.is_a? Hash
          @domains.delete_if {|domain| domain.host == object[:name] }
          return object[:name]
        end
      end
      
      # Replace a virtual host in the Nginx config file
      def replace(options={})
        self.remove options[:name]
        self.add options
      end
      
      # Save any changes made to the Nginx config file, this has to specifically called
      # to be sure it's not accidentally called
      def save
        # self.as_www do
          Cheese::Verbose.log_task "Saving #{@domains.size} domains"
          File.open(@filename, "w+") do |file|
            file.puts TEMPLATES[:header]
            file.puts
            
            @domains.each do |domain|
              Cheese::Verbose.log_task "Adding proxy for #{domain.host}"
              file.puts "#### PROXY #{domain.host} BEGIN ####"
              file.puts proxy_text(domain)
              file.puts "#### PROXY #{domain.host} END ####"
            end
            
            file.puts
            
            @domains.each do |domain|
              Cheese::Verbose.log_task "Adding vhost for #{domain.host}"
              file.puts "#### VHOST #{domain.host} BEGIN ####"
              file.puts vhost_text(domain)
              file.puts "#### VHOST #{domain.host} END ####"
            end
            file.puts TEMPLATES[:footer]
          end
        # end
        Cheese::Verbose.log_task "Saved #{@filename}"
      end
      
      # Stop the Nginx server
      def stop
        Cheese::Verbose.log_task "Stop nginx server" do
          %x{ /etc/init.d/nginx stop }
        end
      end
      
      # Start the Nginx server
      def start
        Cheese::Verbose.log_task "Start nginx server" do
          %x{ /etc/init.d/nginx start }
        end
      end
      
      # Restart the Nginx server
      def restart
        Cheese::Verbose.log_task "Restart nginx server" do
          %x{ /etc/init.d/nginx restart }
        end
      end
    
    private
      
      def as_www
        old_euid, old_uid = Process.euid, Process.uid
        Process.euid, Process.uid = 0, 0 # TODO change to www-data
        begin
          yield
        ensure
          Process.euid, Process.uid = old_euid, old_uid
        end
      end
    
      def load_templates
        TEMPLATES.each do |name, file|
          TEMPLATES[name] = IO.read(File.dirname(__FILE__) + "/../../data/templates/#{file}")
        end
      end
    
      def scan_config
        return false unless File.exists? @filename
        File.open(@filename).each do |line|
          yield line
        end
      end
    
      def clean_domain( domain )
        domain_pieces = domain.split(".")
        return domain_pieces.first == "www" ? domain_pieces[1..-1].join(".") : domain_pieces.join(".")
      end
      
      def vhost_text(domain)
        TEMPLATES[:vhost].gsub("||DOMAIN||", domain.vhost.domain).gsub(
                              "||SHORT_DOMAIN||", domain.vhost.domain.split(".")[0]).gsub(
                              "||PROXY||", "#{domain.vhost.domain.gsub(".", "_")}")
      end
      
      def proxy_text(domain)
        proxy_text = TEMPLATES[:proxy].gsub("||DOMAIN||", "#{domain.vhost.domain.gsub(".", "_")}")
        ports_text = ""
        domain.proxy.ports.each do |port|
          ports_text += "  server 127.0.0.1:#{port};\n"
        end
        proxy_text.gsub("||THREADS||", ports_text)
      end
      
      def find_next_port
        highest_port = 14000
        @domains.each do |domain|
          domain.proxy.ports.each {|port| highest_port = port if port > highest_port }
        end
        highest_port + 10
      end
      
      def new_ports(count)
        start_port = find_next_port
        start_port..(start_port + count)
      end
      
      def find_domains
        @domains = []
        vhosts, proxies = find_vhosts, find_proxies
        vhosts.each do |vhost|
          # find where the domain matches
          vhost_proxy = proxies.detect {|proxy| proxy.domain == vhost.domain }
          @domains << Cheese::Nginx::Domain.new(vhost, vhost_proxy)
        end
      end
    
      def find_vhosts
        vhosts = []
        status = :out
        scan_config do |line|
          case status
          when :out
            if line =~ VHOST_BEGIN
              status = :in
            end
          when :in
            if line =~ VHOST_END
              status = :out
              domain = line.match(VHOST_END)[1]
              vhosts << Cheese::Nginx::VirtualHost.new(domain, self)
            end
          end
        end
        vhosts
      end
      
      def find_proxies
        # TODO refactor this and vhosts
        proxies, status = [], :out
        ports = []
        scan_config do |line|
          case status
          when :out
            if line =~ PROXY_BEGIN
              status = :in
              ports = []
            end
          when :in
            ports << line.match(PROXY_THREAD)[1].to_i if line =~ PROXY_THREAD
            if line =~ PROXY_END
              status = :out
              domain = line.match(PROXY_END)[1]
              proxies << Cheese::Nginx::Proxy.new(domain, ports, self)
            end
          end
        end
        proxies
      end
    end
  end
end