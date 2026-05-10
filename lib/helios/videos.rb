require "helios/videos/version"
require "helios/videos/engine"
require "helios/videos/configuration"
require "helios/videos/processor"
require "helios/videos/processors/cloudflare"
require "helios/videos/processors/mux"

module Helios
  module Videos
    class << self
      def configuration
        @configuration ||= Configuration.new
      end

      def configure
        yield(configuration)
      end

      def processor
        @processor = nil if @processor_type != configuration.processor
        @processor_type = configuration.processor
        @processor ||= case configuration.processor
        when :cloudflare
          Processors::Cloudflare.new(configuration)
        when :mux
          Processors::Mux.new(configuration)
        else
          raise "Unknown video processor: #{configuration.processor}. Use :cloudflare or :mux"
        end
      end
    end
  end
end
