require 'json'
require 'mt/data_api/client'
require 'thor'
require 'yaml'

require 'mtcli/config'

module MTCLI
  # CLI class.
  class CLI < Thor
    desc 'list', 'Show all MT settings'
    def list
      configs = Config.all
      if configs.empty?
        puts 'No MT settings are registered.'
        return
      end

      configs.each do |config|
        puts config
      end
    end

    desc 'show <NAME>', 'Show MT setting'
    def show(name)
      config = Config.get(name)
      unless config
        puts "#{name} is not registered."
        return
      end

      puts config
    end

    desc 'current [NAME]', 'Show/Set current MT setting'
    def current(name = nil)
      if name.nil?
        unless Config.current
          puts 'Current setting does not exist.'
          return
        end

        puts Config.current
      else
        Config.current = name

        puts "Current setting is #{name}."
      end
    end

    desc 'add <NAME> <BASE_URL>', 'Add MT setting'
    def add(name, base_url)
      puts "Cannot add #{name}." unless Config.create(name, base_url: base_url)

      puts "Added #{name}."
    end

    desc 'update <NAME> [arguments]', 'Update MT setting'
    def update(_name)
      puts 'update'
    end

    desc 'delete <NAME>', 'Delete MT setting'
    def delete(name)
      unless Config.delete(name)
        puts "Cannot delete #{name}"
        return
      end

      puts "Deleted #{name}"
    end

    desc 'rename <NAME> <NEW_NAME>', 'Rename MT setting'
    def rename(name, new_name)
      unless Config.get(name)
        puts "#{name} is not registered."
        return
      end
      if Config.get(new_name)
        puts "#{new_name} exists."
        return
      end
      unless Config.rename(name, new_name)
        puts 'Renaming failed.'
        return
      end

      puts "Renamed #{name} to #{new_name}."
    end

    desc 'login <USERNAME> <PASSWORD>', 'Login to current MT'
    def login(username, password)
      config = Config.current
      unless config
        puts 'No current setting.'
        return
      end

      client = MT::DataAPI::Client.new(base_url: config.base_url,
                                       client_id: 'mtcli')
      client.call('authenticate', username: username,
                                  password: password)

      unless client.access_token
        puts 'Login failed.'
        return
      end

      config.access_token = client.access_token
      config.save
      puts 'Login succeeded.'
    end

    desc 'logout', 'Logout from current MT'
    def logout
      config = Config.current
      unless config
        puts 'No current setting.'
        return
      end
      unless config.logged_in?
        puts 'Not logged in.'
        return
      end

      client = MT::DataAPI::Client.new(base_url: config.base_url,
                                       client_id: 'mtcli',
                                       access_token: config.access_token)
      res = client.call('revoke_authentication')
      return unless res['status'] == 'success'

      config.access_token = nil
      config.save
      puts 'Logged out.'
    end

    def respond_to_missing?(method)
      super
    end

    def method_missing(method, *_args)
      config = Config.current
      unless config
        puts 'No current setting.'
        return
      end

      opts = {
        base_url: config.base_url,
        client_id: 'mtcli'
      }
      opts[:access_token] = config.access_token if config.access_token
      client = MT::DataAPI::Client.new(opts)

      begin
        res = client.call(method, options)
        puts res.to_json
        if opts['access_token'] && res['error'] && res['error']['code'] == 401
          config.access_token = nil
          config.save
          puts 'Removed invalid access token.'
        end
      rescue
        puts $ERROR_INFO
      end
    end

    private

    def options
      key = nil
      ARGV[1..-1].each_with_object({}) do |arg, opts|
        if arg =~ /^--/
          if arg =~ /=/
            # key and value
            key, value = arg.sub(/^--/, '').split(/=/)
            opts[key] = value
            key = nil
          else
            # key
            key = arg.sub(/^--/, '')
          end
        elsif key
          # value
          opts[key] = arg
          key = nil
        end
        opts
      end
    end
  end
end
