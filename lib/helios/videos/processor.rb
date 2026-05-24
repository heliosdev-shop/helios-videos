module Helios
  module Videos
    class Processor
      attr_reader :config

      def initialize(config)
        @config = config
      end

      # Ingest a video from its ActiveStorage URL into the video service.
      # Should set video.key and video.playback_urls on success.
      def ingest!(video)
        raise NotImplementedError, "#{self.class}#ingest! must be implemented"
      end

      # Delete a video from the video service.
      def delete!(video)
        raise NotImplementedError, "#{self.class}#delete! must be implemented"
      end

      # Return the playback URL for a video.
      def playback_url(video, signed: false, expiration: 4.hours)
        raise NotImplementedError, "#{self.class}#playback_url must be implemented"
      end

      # Return an HTML player component for the video.
      def player_component(video, muted: false, expiration: 4.hours)
        raise NotImplementedError, "#{self.class}#player_component must be implemented"
      end

      # Generate a signed token for the video (if supported).
      def signed_token(video, expiration: 4.hours)
        raise NotImplementedError, "#{self.class}#signed_token must be implemented"
      end

      # Return a downloadable MP4 URL for the video (used for migration between providers).
      def download_url(video, expiration: 4.hours)
        raise NotImplementedError, "#{self.class}#download_url must be implemented"
      end

      # Ingest a video from an external URL (used during migration between providers).
      # Unlike ingest!, this takes a source URL directly rather than using ActiveStorage.
      # Should set new key and playback_urls on the video without changing provider.
      def ingest_from_url!(video, source_url, provider:)
        raise NotImplementedError, "#{self.class}#ingest_from_url! must be implemented"
      end

      # Check whether a video has finished processing and is ready for playback.
      # Used by migration CheckIngestionJob to poll for readiness.
      def ready?(video)
        raise NotImplementedError, "#{self.class}#ready? must be implemented"
      end

      # Download and store the video thumbnail.
      def download_thumbnail!(video, time: "3s")
        raise NotImplementedError, "#{self.class}#download_thumbnail! must be implemented"
      end
    end
  end
end
