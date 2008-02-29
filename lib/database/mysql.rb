require 'highline/import'
require 'tempfile'

module Cheese
  #
  # Create and remove mysql databases
  #
  class Mysql
    
    # create a user and new db
    def self.create(name)
      puts "What is the root password for MySQL?"
      pass = ask("=> "){|prompt| prompt.echo = "*" }.chomp
      while true
        puts "What is the database password you want for #{name.gsub(".", "_")}?"
        dbpass1 = ask("=> "){|prompt| prompt.echo = "*" }.chomp
        puts "Confirm that"
        dbpass2 = ask("=> "){|prompt| prompt.echo = "*" }.chomp
        if dbpass1.chomp == dbpass2.chomp
          break
        else
          puts "Those passwords didn't match, try again:"
        end
      end
      puts "adding db and user"
      tmpfile = Tempfile.new("mysql-create")
      tmpfile.puts "CREATE DATABASE #{name.gsub(".", "_")};"
      tmpfile.puts "GRANT SELECT,INSERT,UPDATE,DELETE,CREATE,DROP ON *.* TO '#{name.gsub(".", "_")}'@'localhost' IDENTIFIED BY '#{dbpass1}';"
      tmpfile.close
      %x{ mysql -u root -p#{pass} mysql < #{tmpfile.path} }
    end
    
    # remove a user and new db
    def self.remove(name)
      puts "What is the root password for MySQL?"
      pass = ask("=> "){|prompt| prompt.echo = "*" }
      
      tmpfile = Tempfile.new("mysql-drop")
      tmpfile.puts "DROP DATABASE #{name.gsub(".", "_")};"
      tmpfile.puts "DROP USER '#{name.gsub(".", "_")}'@'localhost';"
      tmpfile.close
      %x{ mysql -u root -p#{pass} < #{tmpfile.path} }
    end
    
  end
  
end