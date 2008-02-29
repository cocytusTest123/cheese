#!/usr/bin/env ruby
# cheese-setup.rb
#
# Configure cheese-tools defaults and misc information
# This is a simple run-once script which needs LOTS of refactoring and cleanup
#

require 'rubygems'
require 'highline/import'
require 'fileutils'
require 'yaml'

def draw_line(count=20)
  @line = '-' * count
  say "<%= color(@line, :horizontal_line) %>"
end

def draw_box
  draw_line 50
  yield
  draw_line 50
end

CHEESE_CONF = "/etc/cheese/cheese.conf"
SUPPORTED_SCMS = { 
  :svn =>   { :name => 'Subversion', :binary => 'svnserve' } }
SUPPORTED_DBS =  { 
  :psql =>  { :name => 'Postgresql', :binary => 'psql' },
  :mysql => { :name => 'MySQL', :binary => 'mysql' } }
SILENCER = ">/dev/null 2>/dev/null"
begin
  FileUtils.mkdir '/etc/cheese' unless File.exists? '/etc/cheese'
  FileUtils.touch CHEESE_CONF
  
  preferences = {}
  
  # Create a color scheme, naming color patterns with symbol names.
  ft = HighLine::ColorScheme.new do |cs|
          cs[:headline]         = [ :bold, :yellow ]
          cs[:horizontal_line]  = [ :bold, :white ]
          cs[:important]        = [ :bold, :red ]
       end

  # Assign that color scheme to HighLine...
  HighLine.color_scheme = ft

  say "<%= color('Welcome to the cheese setup utility', :headline) %>"
  draw_line 37
  
  say "Answer each of the following questions and then you'll be"
  say "ready to start using cheese:"

  # SCM
  choose do |menu|
    SUPPORTED_SCMS.each do |scm, details|
      menu.choice(scm, details[:name]) do |command, extras|
        preferences[:scm] = { :name => details[:name], :binary => details[:binary]}
        say "What would you like the default #{details[:name]} username to be?"
        preferences[:scm_user] = ask("=> ", String)
        say "and what password would you like?"
        preferences[:scm_pass] = ask("=> ", String){|prompt| prompt.echo = "*" }
      end
    end
    menu.choice(:skip, "You don't want to use one") do |command, details|
      preferences[:scm] = :skip
    end
    menu.choice(:quit, "Exit setup") { exit }
  end
  
  # Database
  say "What database engine are you using?"
  choose do |menu|
    SUPPORTED_DBS.each do |db, details|
      menu.choice(db, details[:name]) do |command, extras|
        preferences[:database_type] = { :name => details[:name], :binary => details[:binary] }
      end
    end
    menu.choice(:skip, "You don't want to use one") do |command, details|
      preferences[:database_type] = :skip
    end
    menu.choice(:quit, "Exit setup") { exit }
  end
  
  # Rails stack combination
  say "What Ruby on Rails stack are you using?"
  choose do |menu|
    menu.choice(:nginx, "Nginx with Mongrel") do |command, details|
      preferences[:stack] = :nginx
    end
    menu.choice(:skip, "You don't want to use one") do |command, details|
      preferences[:scm] = :skip
    end
    menu.choice(:quit, "Exit setup") { exit }
  end
  
  draw_box do
    say "<%= color('You need a normal account for safety reasons, running as', :bold) %>"
    say "<%= color('root is dangerous, so we need to do that', :bold) %>"
  end
  
  user = ask("What username would you like for logging into the system?", String)
  unless user.empty?
    preferences[:user] = user
    %x{ useradd -c "Cheesey User" -d /home/#{preferences[:user].chomp} --create-home #{preferences[:user].chomp} #{SILENCER} }
    say "and what password would you like to use with that?"
    %x{ passwd #{preferences[:user]} }
    %x{ addgroup scm #{SILENCER} }
    %x{ usermod -g scm #{preferences[:user]} }
  else
    say "Skipping user creation (I assume you must have done this already then)"
  end
  
  say "Saving and setting up those selected options"
  
  scm = %x{ which #{ preferences[:scm][:binary] } }
  xinetd_service = <<-EOF
    service #{ preferences[:scm][:binary] }
    {
      socket_type = stream
      protocol = tcp
      user = scm
      wait = no
      disable = no
      server = #{ scm.chomp }
      server_args = -i --root=/var/src
      port = 3690
    }
    EOF
  File.open("/etc/xinetd.d/#{preferences[:scm][:binary]}", 'w+') do |file|
    file.puts xinetd_service
  end
  %x{ /etc/init.d/xinetd restart #{SILENCER} }
  
  File.open(CHEESE_CONF, "w+", 0640) {|f| YAML.dump(preferences, f)}
  
  say "Done"
  
rescue Errno::EPERM
  puts "This script must be run with root privileges"
  exit
rescue Errno::EACCES
  puts "This script must be run with root privileges"
  exit
end