module Helios
  module Videos
    module Migration
      # Orchestrator job: finds all videos on the source provider and enqueues
      # a ConvertVideoJob for each one. Processes record-by-record so long
      # ingestions don't block each other.
      class MigrateVideosJob < Helios::Videos::ApplicationJob
        queue_as :default

        # @param from [String] source provider ("cloudflare" or "mux")
        # @param to [String] destination provider ("cloudflare" or "mux")
        # @param batch_size [Integer] how many to enqueue per run (default: all)
        # @param use_original [Boolean] if true, ingest from the original S3 file
        #   (via ActiveStorage) instead of downloading from the source provider.
        #   Useful if you want higher quality unprocessed source files. Requires
        #   that the original uploads still exist in your storage bucket.
        def perform(from:, to:, batch_size: nil, use_original: false)
          video_class = Helios::Videos.video_class

          videos = video_class.where(provider: from).where.not(key: [nil, ""])
          videos = videos.limit(batch_size) if batch_size.present?

          total = videos.count
          Rails.logger.info("[helios-videos] Migration: enqueuing #{total} videos from #{from} -> #{to} (use_original: #{use_original})")

          videos.find_each do |video|
            ConvertVideoJob.perform_later(video_id: video.id, from: from, to: to, use_original: use_original)
          end

          Rails.logger.info("[helios-videos] Migration: all #{total} conversion jobs enqueued")
        end
      end
    end
  end
end
