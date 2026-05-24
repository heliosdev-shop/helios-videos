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
        def perform(from:, to:, batch_size: nil)
          video_class = Helios::Videos.video_class

          videos = video_class.where(provider: from).where.not(key: [nil, ""])
          videos = videos.limit(batch_size) if batch_size.present?

          total = videos.count
          Rails.logger.info("[helios-videos] Migration: enqueuing #{total} videos from #{from} -> #{to}")

          videos.find_each do |video|
            ConvertVideoJob.perform_later(video_id: video.id, from: from, to: to)
          end

          Rails.logger.info("[helios-videos] Migration: all #{total} conversion jobs enqueued")
        end
      end
    end
  end
end
