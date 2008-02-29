require 'fileutils'

module Cheese
  module Subversion
    #
    # Represents the a subversion repository
    # This could be done with the svn ruby bindings, but it's simple
    # stuff that for now will be fine using system
    #
    class Repository
      DEFAULT_ACCESS = { :anon => :none, :auth => :write }
      SILENCER = ">/dev/null 2>/dev/null"
      
      # Create a Subversion repository for the given name this 
      # calls create_tmp_structure to give the tags, branches and trunk
      # directories
      def self.create(name)
        # Create the repo
        %x{ svnadmin create /var/src/#{name} #{SILENCER} }
        %x{ chown svn:svn /var/src/#{name} #{SILENCER} }
        %x{ chmod -R 774 /var/src/#{name} #{SILENCER} }
      
        folder = self.create_tmp_structure
        self.import(name, folder)
      end
      
      # Create the default file structure
      def self.create_tmp_structure
        FileUtils.mkdir_p(  File.join(Dir.tmpdir, "/svn_structure/branches")) unless File.exists? File.join(Dir.tmpdir, "/svn_structure/branches")
        FileUtils.mkdir(    File.join(Dir.tmpdir, "/svn_structure/trunk"))    unless File.exists? File.join(Dir.tmpdir, "/svn_structure/trunk")
        FileUtils.mkdir(    File.join(Dir.tmpdir, "/svn_structure/tags"))     unless File.exists? File.join(Dir.tmpdir, "/svn_structure/tags")
        File.join(Dir.tmpdir, "/svn_structure")
      end
      
      # Set the permissions on a repository, defaults are anon-access: none and auth-access: write.
      # These options can be changed with options
      #
      # ==== Options
      # +options+
      #   +access+: A Hash containing :anon and :auth which can be set to either :none, :read or :write
      #   +users+:  An Array or Hash containing user/pass combinations 
      #             e.g. { :name => "Jamie", :password => "Chees3y" }
      def self.set_permissions(options={})
        access = options.delete(:access) || DEFAULT_ACCESS
        name = options.delete(:name)
        File.open("/var/src/#{name}/conf/svnserve.conf", "w+") do |file|
          file.puts "# Generated on #{Time.now.to_s}"
          file.puts "[general]"
          file.puts "anon-access = #{access[:anon].to_s}"
          file.puts "auth-access = #{access[:auth].to_s}"
          file.puts "password-db = passwd"
        end
        File.open("/var/src/#{name}/conf/passwd", "w+") do |file|
          file.puts "[users]"
          if options[:users].is_a?Array
            options[:users].each do |user, pass|
              file.puts "#{user} = #{pass}"
            end
          elsif options[:users].is_a?Hash
            file.puts "#{options[:users][:user]} = #{options[:users][:pass]}"
          end
        end
      end
      
      def self.remove(name)
        FileUtils.rm_rf("/var/src/#{name}")
      end
      
      def self.import(name, files=[], extra_path="")
        files.each do |file|
          %x{ svn import #{file} file:///var/src/#{name}#{extra_path} -m "import of #{file}" }
        end
      end
      
      def self.remove_file(name, files=[])
        if files.is_a?Array
          files.each do |file|
            %x{ svn delete #{file} file:///var/src/#{name} -m "deleted #{file}" #{SILENCER} } if File.exists? file
          end
        else
          %x{ svn delete #{files} file:///var/src/#{name} -m "deleted #{files} #{SILENCER}" } if File.exists? files
        end
      end
    end
  end
end