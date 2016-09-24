module MTCLI
  # common methods.
  module Util
    def symbolize_keys(data)
      if data.is_a?(Hash)
        data.reduce({}) do |h, (k, v)|
          h.merge(k.to_sym => symbolize_keys(v))
        end
      elsif data.is_a?(Array)
        data.map { |d| symbolize_keys(d) }
      else
        data
      end
    end

    module_function :symbolize_keys
  end
end
