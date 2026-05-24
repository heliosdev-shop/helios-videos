module Helios
  module Videos
    module Migration
      # Per-video conversion job: gets a download URL from the source provider,
      # submits it to the destination provider for ingestion, and updates the
      # video record.
      #
      # For Mux destinations, the playback ID comes back immediately so the
      # provider is flipped right away.
      #
      # For Cloudflare destinations, a CheckIngestionJob is enqueued to poll
      # for readiness before flipping the provider.
      class ConvertVideoJob < Helios::Videos::ApplicationJob
        queue_as :default

        # @param video_id [Integer]
        # @param from [String] source provider
        # @param to [String] destination provider
        # @param use_original [Boolean] if true, use the original S3 file instead
        #   of downloading from the source provider
        def perform(video_id:, from:, to:, use_original: false)
          video = Helios::Videos.video_class.find(video_id)

          unless video.provider == from
            Rails.logger.info("[helios-videos] Migration: video #{video_id} is already on #{video.provider}, skipping")
            return
          end

          source_processor = Helios::Videos.processor_for(from.to_sym)
          dest_processor = Helios::Videos.processor_for(to.to_sym)

          # Get source URL — either from the original S3 upload or from the current provider
          if use_original
            unless video.video_file.attached?
              Rails.logger.error("[helios-videos] Migration: video #{video_id} has no original file attached, falling back to provider download")
              source_url = source_processor.download_url(video, expiration: 12.hours)
            else
              source_url = video.video_file.url
              Rails.logger.info("[helios-videos] Migration: using original S3 file for video #{video_id}")
            end
          else
            source_url = source_processor.download_url(video, expiration: 12.hours)
          end

          unless source_url.present?
            Rails.logger.error("[helios-videos] Migration: could not get download URL for video #{video_id}")
            return
          end

          Rails.logger.info("[helios-videos] Migration: ingesting video #{video_id} from #{from} -> #{to}")

          # Submit to destination processor
          dest_processor.ingest_from_url!(video, source_url, provider: to)

          if to.to_sym == :mux
            # Mux returns playback IDs immediately — flip provider now
            video.update!(provider: to)
            Rails.logger.info("[helios-videos] Migration: video #{video_id} migrated to #{to}")

            # Download new thumbnail from the new provider
            dest_processor.download_thumbnail!(video)
          else
            # Cloudflare needs processing time — enqueue a check
            CheckIngestionJob.set(wait: 30.seconds).perform_later(
              video_id: video_id,
              to: to,
              attempt: 1
            )
          end
        end
      end
    end
  end
end
