module Helios
  module Videos
    module VideoConcern
      extend ActiveSupport::Concern

      included do
        has_one_attached :video_file
        has_one_attached :thumbnail_image

        enum :provider, { cloudflare: 'cloudflare', mux: 'mux' }

        if defined?(Helios::Press::Block)
          belongs_to :block, class_name: "Helios::Press::Block", optional: true
        end

        before_validation :set_default_provider, on: :create
        after_create :enqueue_check_for_video
        before_destroy :delete_from_service
      end

      # Returns the processor for this specific video based on its provider column,
      # falling back to the globally configured processor.
      def effective_processor
        if respond_to?(:provider) && provider.present?
          Helios::Videos.processor_for(provider.to_sym)
        else
          Helios::Videos.processor
        end
      end

      def player_component(muted: false, expiration: 4.hours)
        effective_processor.player_component(self, muted: muted, expiration: expiration)
      end

      def playback_url(signed: false, expiration: 4.hours)
        effective_processor.playback_url(self, signed: signed, expiration: expiration)
      end

      def signed_url(expiration: 4.hours)
        playback_url(signed: true, expiration: expiration)
      end

      def download_url(expiration: 4.hours)
        effective_processor.download_url(self, expiration: expiration)
      end

      def download_and_store_thumbnail!(time: "3s")
        effective_processor.download_thumbnail!(self, time: time)
      end

      def thumbnail_url(time: "4s")
        thumbnail_image.attached? ? thumbnail_image : nil
      end

      def requires_signed_urls?
        respond_to?(:requires_signed_urls) ? super : false
      end

      def check_for_processing!
        effective_processor.ingest!(self)
      end

      private

      def set_default_provider
        self.provider ||= Helios::Videos.configuration.processor.to_s
      end

      def enqueue_check_for_video
        Helios::Videos::CheckVideoJob.perform_later(video: self)
      end

      def delete_from_service
        effective_processor.delete!(self)
      rescue => e
        Rails.logger.warn("[helios-videos] Failed to delete video #{id} from service: #{e.message}")
        true # Don't block destroy
      end
    end
  end
end
