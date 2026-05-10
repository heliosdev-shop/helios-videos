module Helios
  module Videos
    class CheckVideoJob < ApplicationJob
      queue_as :default

      def perform(video:, attempt_thumbnail: false)
        if video.key.present?
          Rails.logger.debug("[helios-videos] Video #{video.id} already ingested (key: #{video.key})")

          if attempt_thumbnail && !video.thumbnail_image.attached?
            success = video.download_and_store_thumbnail!
            unless success
              CheckVideoJob.set(wait: 30.seconds).perform_later(video: video, attempt_thumbnail: true)
            end
          end
          return
        end

        if video.video_file.attached?
          Rails.logger.debug("[helios-videos] Video #{video.id} file attached, starting ingestion...")
          video.check_for_processing!

          # Schedule thumbnail download after processing
          CheckVideoJob.set(wait: 10.seconds).perform_later(video: video, attempt_thumbnail: true)
        else
          Rails.logger.debug("[helios-videos] Video #{video.id} file not attached, retrying in 5s...")
          CheckVideoJob.set(wait: 5.seconds).perform_later(video: video, attempt_thumbnail: attempt_thumbnail)
        end
      end
    end
  end
end
