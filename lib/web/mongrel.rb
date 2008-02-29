require 'tmpdir'

module Cheese
  #
  # Representing the Mongrel cluster config file, this will be expanded/refactored 
  # to include controlling mongrel too
  class Mongrel
    
    # Create a temp file which has the right config for the given host and ports
    # and import it into the Subversion repository for this domain
    def self.create(host, ports)
      mongrel_text = IO.read(File.dirname(__FILE__) + "/../../data/templates/mongrel.inc")
      count = ports.size
      mongrel_text.gsub!("||PORT||", ports[0].to_s).gsub!("||THREADS||", count.to_s).gsub!("||DOMAIN||", host)
      
      FileUtils.mkdir_p(  File.join(Dir.tmpdir, "/config")) unless File.exists? File.join(Dir.tmpdir, "/config")
      File.open(File.join(Dir.tmpdir, "/config/mongrel_cluster.yml"), "w+") { |file| file.puts mongrel_text }
      Cheese::Subversion::Repository.import(host, File.join(Dir.tmpdir, "/config"), "/trunk/config")
    end
    
    # Requests that Subversion deletes the given config file for a host
    def self.remove(host)
      Cheese::Subversion::Repository.remove_file(host, "/config/mongrel_cluster.yml")
    end
    
  end
  
end