# controller.rb
#
# Validate the options given and delegate jobs to the other classes
#

begin
  require 'rubygems'
rescue LoadError
  # no rubygems to load, so we fail silently
end

require 'yaml'
require 'process'
require 'verbose'
require 'database/mysql'
require 'database/postgresql'
require 'scm/subversion'
require 'web/domain'
require 'web/mongrel'
require 'web/nginx'
require 'web/proxy'
require 'web/virtual_host'

module Cheese
  class Controller
    
    CHEESE_CONF = "/etc/cheese/cheese.conf"
    NGINX_CONF  = '/etc/nginx/nginx.conf'
    
    def initialize(options={})
      # Check cheese --setup has been run
      unless File.exists?(CHEESE_CONF)
        puts "Please run cheese --setup before using any cheese actions."
        exit
      end
      # Need a better way of doing this, so it works in all files
      Cheese::Verbose.dry_run = options.delete(:dry_run)
      Cheese::Verbose.loud = options.delete(:verbose)
      @preferences = YAML.load(File.open(CHEESE_CONF))
      @options = options
      run_actions
    end

private
    
    # Run all actions necessary
    def run_actions
      # List vhosts
      if ( @options[:actions].include?(:web_server) || @options[:actions].include?(:list_vhosts))
        @nginx = Cheese::Nginx::Config.new(NGINX_CONF)
      end
      
      if @options[:actions].include? :list_vhosts
        Cheese::Verbose.log_task("listing vhosts in nginx.conf") do
          begin
            @nginx.domains.each_with_index {|domain, i| puts "#{i}. #{domain.vhost.domain} - #{domain.proxy.ports.size} threads" }
          rescue Exception => e
            puts "Error listing vhosts:"
            puts e.message
            puts "exiting"
            exit
          end
        end
      end

      # Nginx
      if @options[:actions].include? :web_server
        begin
          Cheese::Verbose.log_task("back up nginx.conf") do
            FileUtils.cp(NGINX_CONF, NGINX_CONF + ".old") if File.exists?(NGINX_CONF)
          end
        rescue Errno::EPERM
          puts "This script must be run with root privileges"
          exit
        rescue Errno::EACCES
          puts "This script must be run with root privileges"
          exit
        end
        
        case @options[:remove]
        when false
          Cheese::Verbose.log_task("create nginx vhost (#{@options[:name]})") do
            @added_domain = @nginx.add @options
          end
        when true
          Cheese::Verbose.log_task("remove nginx vhost (#{@options[:name]})") do 
            @removed_domain = @nginx.remove @options
          end
        end
        
        @nginx.save
        @nginx.restart
      end
      
      # Subversion
      if @options[:actions].include? :scm
        if @options[:remove]
          Cheese::Verbose.log_task("remove subversion repository (#{@options[:name]})") do
            svn = Cheese::Subversion::Repository.remove @options[:name]
          end
        else
          Cheese::Verbose.log_task("add subversion repository (#{@options[:name]})") do
            svn = Cheese::Subversion::Repository.create @options[:name]
          end
          Cheese::Verbose.log_task("set the default permissions on the repository") do
            user, pass = @preferences[:scm_user].chomp, @preferences[:scm_pass].chomp
            Cheese::Subversion::Repository.set_permissions( :name => @options[:name],
                                                            :access => {:anon => :none, :auth => :write},
                                                            :users => {:user => user, :pass => pass})
          end
        end
      end

      # Mongrel cluster file
      if @options[:actions].include? :app_server
        if @options[:remove]
          Cheese::Verbose.log_task("remove the mongrel_cluster file") do
            Cheese::Mongrel.remove(@removed_domain)
          end
        else
          Cheese::Verbose.log_task("create the mongrel_cluster file") do
            Cheese::Mongrel.create(@options[:name], @added_domain.proxy.ports)
          end
        end
      end
      
      # Database
      if @options[:actions].include? :database
        if @options[:remove]
          Cheese::Verbose.log_task("drop a database") do
            Cheese::Verbose.log_task(" requiring lib/#{@options[:database_type]}")
            require "database/#{@options[:database_type]}"
            Cheese::Verbose.log_task(" creating class #{@options[:database_type].to_s.capitalize}")
            db_klass = Cheese.const_get(@options[:database_type].to_s.capitalize.intern)
            Cheese::Verbose.log_task(" executing remove command on #{@options[:name]}")
            db_klass.remove(@options[:name])
          end
        else
          Cheese::Verbose.log_task("create a database") do
            Cheese::Verbose.log_task(" requiring lib/#{@options[:database_type]}")
            require "database/#{@options[:database_type]}"
            Cheese::Verbose.log_task(" creating class #{@options[:database_type].to_s.capitalize}")
            db_klass = Cheese.const_get(@options[:database_type].to_s.capitalize.intern)
            Cheese::Verbose.log_task(" executing create command")
            db_klass.create(@options[:name])
          end
        end
      end
    end
    
  end
end