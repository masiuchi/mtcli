require 'mt/data_api/client/endpoint_manager'
require 'yaml'

require 'mtcli/util'

module MTCLI
  # configuration file class.
  class Config
    include Util

    CONFIG_DIRECTORY = '.mtcli'.freeze
    CURRENT_BASENAME = '.CURRENT'.freeze
    YAML_EXTENSION   = '.yml'.freeze

    attr_accessor :access_token, :base_url, :endpoints, :version

    def initialize(file_path, hash = {})
      @file_path = file_path
      @version   = MT::DataAPI::Client::EndpointManager::DEFAULT_API_VERSION
      set(hash)
    end

    def self.all
      pattern = File.join(config_dir, '*' + YAML_EXTENSION)
      Dir.glob(pattern).map do |file_path|
        get(file_path)
      end
    end

    def self.get(basename)
      f = file_path(basename)
      return nil unless File.exist?(f)
      hash = YAML.load_file(f)
      new(f, hash)
    end

    def self.create(basename, hash)
      get(basename) && (return nil)
      f = file_path(basename)
      config = new(f, hash)
      config.save
      config
    end

    def self.update(basename, hash)
      (config = get(basename)) || (return nil)
      config.set(hash)
      config.save
      config
    end

    def self.delete(basename)
      (config = get(basename)) || (return nil)
      config.delete
      config
    end

    def self.rename(basename, new_basename)
      (config = get(basename)) || (return nil)
      config.rename(new_basename) || (return nil)
      config
    end

    def self.current
      get(real_current_file_path)
    end

    def self.current=(basename)
      (config = get(basename)) || (return nil)
      return config if config.current?
      config.set_current
      config
    end

    def self.delete_current
      return false unless File.exist?(current_file_path)
      File.delete(current_file_path) == 1 || raise
    end

    def self.config_dir
      File.join(ENV['HOME'], CONFIG_DIRECTORY)
    end

    def self.file_path(basename)
      return basename if !basename || basename[0] == '/'
      File.join(config_dir, basename + YAML_EXTENSION)
    end

    def self.current_file_path
      file_path(CURRENT_BASENAME)
    end

    def self.real_current_file_path
      f = current_file_path
      return nil unless File.exist?(f) && File.ftype(f) == 'link'
      File.readlink(f)
    end

    def save
      raise unless @base_url || @base_url.empty?
      File.open(@file_path, 'w') do |file|
        YAML.dump(to_hash, file)
      end
      true
    end

    def set_current
      self.class.delete_current
      File.symlink(@file_path, self.class.current_file_path).zero? || raise
    end

    def to_s
      hash = stringify_keys(basename => {
                              base_url: @base_url,
                              current:  current?,
                              login:    logged_in?,
                              version:  @version
                            })
      YAML.dump(hash)
    end

    def logged_in?
      @access_token && !@access_token.empty? ? true : false
    end

    def current?
      @file_path == self.class.real_current_file_path ? true : false
    end

    private

    def basename
      File.basename(@file_path, '.*')
    end

    def delete
      self.class.delete_current if current?
      File.delete(@file_path) == 1 || raise
    end

    def rename(new_basename)
      return nil if self.class.get(new_basename)
      current = current?
      new_f = self.class.file_path(new_basename)
      File.rename(@file_path, new_f).zero? || raise
      set_current if current
    end

    def set(hash)
      hash = symbolize_keys(hash)
      @access_token = hash[:access_token] if hash.key?(:access_token)
      @base_url     = hash[:base_url]     if hash.key?(:base_url)
      @endpoints    = hash[:endpoints]    if hash.key?(:endpoints)
      @version      = hash[:version]      if hash.key?(:version)
      @current      = hash[:current]      if hash.key?(:current)
    end

    def to_hash
      {
        access_token: @access_token,
        base_url:     @base_url,
        endpoints:    @endpoints,
        version:      @version
      }
    end

    def stringify_keys(data)
      if data.is_a?(Hash)
        data.reduce({}) do |h, (k, v)|
          h.merge(k.to_s => stringify_keys(v))
        end
      elsif data.is_a?(Array)
        data.map { |d| stringify_keys(d) }
      else
        data
      end
    end
  end
end
