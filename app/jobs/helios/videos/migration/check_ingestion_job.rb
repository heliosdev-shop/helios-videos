module Helios
  module Videos
    module Migration
      # Polls the destination provider (Cloudflare) to check if a migrated video
      # has finished processing. Once ready, flips the provider column.
      #
      # Only needed for Cloudflare as a destination — Mux returns playback IDs
      # immediately so no polling is required.
      class CheckIngestionJob < Helios::Videos::ApplicationJob
        queue_as :default

        MAX_ATTEMPTS = 60 # ~30 minutes with 30s intervals

        # @param video_id [Integer]
        # @param to [String] destination provider
        # @param attempt [Integer] current attempt number
        def perform(video_id:, to:, attempt: 1)
          video = Helios::Videos.video_class.find(video_id)
          dest_processor = Helios::Videos.processor_for(to.to_sym)

          if dest_processor.ready?(video)
            video.update!(provider: to)
            Rails.logger.info("[helios-videos] Migration: video #{video_id} is ready on #{to}, provider flipped (attempt #{attempt})")

            dest_processor.download_thumbnail!(video)
          elsif attempt >= MAX_ATTEMPTS
            Rails.logger.error("[helios-videos] Migration: video #{video_id} still not ready after #{MAX_ATTEMPTS} attempts, giving up")
          else
            Rails.logger.info("[helios-videos] Migration: video #{video_id} not yet ready on #{to}, retrying (attempt #{attempt})")
            CheckIngestionJob.set(wait: 30.seconds).perform_later(
              video_id: video_id,
              to: to,
              attempt: attempt + 1
            )
          end
        end
      end
    end
  end
end
