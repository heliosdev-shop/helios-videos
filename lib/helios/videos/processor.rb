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

      # Download and store the video thumbnail.
      def download_thumbnail!(video, time: "3s")
        raise NotImplementedError, "#{self.class}#download_thumbnail! must be implemented"
      end
    end
  end
end
