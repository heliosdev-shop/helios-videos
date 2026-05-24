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

      def video_class
        configuration.video_model.constantize
      end

      def processor
        @processor = nil if @processor_type != configuration.processor
        @processor_type = configuration.processor
        @processor ||= processor_for(configuration.processor)
      end

      def processor_for(provider_type)
        case provider_type.to_sym
        when :cloudflare
          Processors::Cloudflare.new(configuration)
        when :mux
          Processors::Mux.new(configuration)
        else
          raise "Unknown video processor: #{provider_type}. Use :cloudflare or :mux"
        end
      end
    end
  end
end
