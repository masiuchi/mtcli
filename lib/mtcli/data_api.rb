require 'json'
require 'net/http'
require 'uri'

require 'mtcli/util'

module MTCLI
  class DataAPI

    include Util

    DEFAULT_CLIENT_ID = 'mt-data-api-sdk-ruby'
    DEFAULT_VERSION   = 3

    attr :access_token

    def initialize(opts)
      opts = symbolize_keys(opts)

      @base_url     = opts[:base_url]
      @client_id    = opts[:client_id] || DEFAULT_CLIENT_ID
      @version      = opts[:version]   || DEFAULT_VERSION
      @access_token = opts[:access_token]
      @endpoints    = opts[:endpoints]

      unless @base_url
        raise ArgumentError.new('parameter "base_url" is required')
      end
      @base_url.gsub!(/\/$/, '')
      @version = @version.to_s.sub(/^v/, '').to_i
    end

    def list_endpoints(opts={})
      url = generate_url('/endpoints')
      request_get(url, opts)
    end

    def method_missing(method, *args)
      method   = method.to_s
      endpoint = find_endpoint(method)
      unless endpoint
        raise NoMethodError.new("no endpoint: #{method}", method, args)
      end
      send_request(endpoint, args)
    end

    private

    def find_endpoint(method)
      unless @endpoints
        res = list_endpoints
        raise res if res['error']
        @endpoints = res['items']
      end
      endpoints = @endpoints.select do |ep|
        ep['id'] == method && @version >= ep['version']
      end
      endpoints.sort {|a, b| b['version'] <=> a['version'] }
               .first
    end

    def send_request(endpoint, args)
      args = args.first || {}
      raise 'parameters should be Hash' unless args.is_a?(Hash)
      args = symbolize_keys(args)

      if endpoint['id'] == 'authenticate'
        unless args.has_key?('clientId') || args.has_key?(:clientId)
          args.merge!(clientId: @client_id)
        end
      end

      url = generate_url(endpoint['route'], args)

      case endpoint['verb']
      when 'GET' then
        res = request_get(url, args)
      when 'POST' then
        res = request_post(url, args)
      when 'PUT' then
        res = request_put(url, args)
      when 'DELETE' then
        res = request_delete(url)
      else
        raise "unknown method: #{endpoint['verb']}"
      end

      if endpoint['id'] == 'authenticate'
        @access_token = res['accessToken']
      end

      res
    end

    def generate_url(route, args={})
      route.scan(/:[^:\/]+(?=\/|$)/).each do |m|
        key = m.sub(/^:/, '').to_sym
        value = args.delete(key)
        raise "parameter \"#{key}\" is requred" unless value
        route.sub!(/#{m}/, value.to_s)
      end
      "#{@base_url}/v#{@version.to_s + route}"
    end

    def add_query_to_url(url, opts)
      query = opts.keys.sort.reduce('') do
        |str, key| str << [key, opts[key]].join('=')
      end
      query.length > 0 ? "#{url}?#{query}" : url
    end

    def request_get(url, opts={})
      url = add_query_to_url(url, opts)
      uri = URI.parse(url)
      req = Net::HTTP::Get.new(uri)
      request_common(uri, req)
    end

    def request_post(url, opts)
      uri = URI.parse(url)
      req = Net::HTTP::Post.new(uri)
      req.set_form_data(opts)
      request_common(uri, req)
    end

    def request_put(url, opts)
      uri = URI.parse(url)
      req = Net::HTTP::Put.new(uri)
      req.set_form_data(opts)
      request_common(uri, req)
    end

    def request_delete(url)
      uri = URI.parse(url)
      req = Net::HTTP::Delete.new(uri)
      request_common(uri, req)
    end

    def request_common(uri, req)
      if @access_token
        req['X-MT-Authorization'] = "MTAuth accessToken=#{@access_token}"
      end
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true if uri.scheme == 'https'
      res = http.start { http.request(req) }
      JSON.parse(res.body)
    end

  end
end

