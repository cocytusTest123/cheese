module Cheese
  #
  # Create and remove postgresql databases
  #
  class Postgresql
    SILENCER = ">/dev/null 2>/dev/null"
    
    # create a user and new db
    def self.create(name)
      while
        puts "We need to set a database password for #{name.gsub(".", "_")}."
      end
      
      %x{ su -c "createuser -S -D -R #{name.gsub(".", "_")} -W" postgres }
      %x{ su -c "createdb #{name.gsub(".", "_")}" postgres #{SILENCER} }
    end
    
    # remove a user and new db
    def self.remove(name)
      %x{ su -c "dropuser #{name.gsub(".", "_")}" postgres #{SILENCER} }
      %x{ su -c "dropdb #{name.gsub(".", "_")}" postgres #{SILENCER} }
    end
    
  end
  
end