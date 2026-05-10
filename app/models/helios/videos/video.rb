module Helios
  module Videos
    class Video < ActiveRecord::Base
      self.table_name = "helios_videos_videos"

      # Optional association to helios-press block (when both gems are loaded)
      if defined?(Helios::Press::Block)
        belongs_to :block, class_name: "Helios::Press::Block", optional: true
      end

      has_one_attached :video_file
      has_one_attached :thumbnail_image

      after_create :enqueue_check_for_video
      before_destroy :delete_from_service

      def player_component(muted: false, expiration: 4.hours)
        Helios::Videos.processor.player_component(self, muted: muted, expiration: expiration)
      end

      def playback_url(signed: false, expiration: 4.hours)
        Helios::Videos.processor.playback_url(self, signed: signed, expiration: expiration)
      end

      def signed_url(expiration: 4.hours)
        playback_url(signed: true, expiration: expiration)
      end

      def download_and_store_thumbnail!(time: "3s")
        Helios::Videos.processor.download_thumbnail!(self, time: time)
      end

      def thumbnail_url(time: "4s")
        thumbnail_image.attached? ? thumbnail_image : nil
      end

      def requires_signed_urls?
        respond_to?(:requires_signed_urls) ? requires_signed_urls : false
      end

      def check_for_processing!
        Helios::Videos.processor.ingest!(self)
      end

      private

      def enqueue_check_for_video
        CheckVideoJob.perform_later(video: self)
      end

      def delete_from_service
        Helios::Videos.processor.delete!(self)
      rescue => e
        Rails.logger.warn("[helios-videos] Failed to delete video #{id} from service: #{e.message}")
        true # Don't block destroy
      end
    end
  end
end
