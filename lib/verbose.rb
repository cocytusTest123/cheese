module Cheese
  #
  # This is a wrapper around actions that can be taken, it allows you 
  # to control the verbosity and also 'fake' an action on a dry run.
  class Verbose
    @@loud    = false
    @@dry_run = false
    
    def self.log_task(message="")
      if block_given?
        if @@dry_run
          if @@loud
            puts "faking: #{message}"
            puts "done"
          end
        else
          puts "doing: #{message}" if @@loud
          yield
          puts "done" if @@loud
        end
      else
        puts message if @@loud
      end
    end
    
    def self.loud=(enable=true)
      @@loud = enable
    end
    
    def self.dry_run=(enable=true)
      @@dry_run = enable
      @@loud = enable
    end
  end
end