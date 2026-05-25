module Helios
  module Videos
    module Processors
      class Mux < Processor
        def ingest!(video)
          return if video.key.present?
          return unless video.video_file.attached?

          require "mux_ruby"

          MuxRuby.configure do |c|
            c.username = config.mux_token_id
            c.password = config.mux_token_secret
          end

          assets_api = MuxRuby::AssetsApi.new
          input_settings = MuxRuby::InputSettings.new(url: video.video_file.url)
          create_request = MuxRuby::CreateAssetRequest.new(
            input: [input_settings],
            playback_policy: [MuxRuby::PlaybackPolicy::PUBLIC]
          )

          response = assets_api.create_asset(create_request)
          asset = response.data

          video.update!(
            key: asset.id,
            playback_urls: { "hls" => "https://stream.mux.com/#{asset.playback_ids&.first&.id}.m3u8" }
          )

          Rails.logger.info("[helios-videos] Video #{video.id} ingested into Mux: #{video.key}")
        end

        def ingest_from_url!(video, source_url, provider:)
          require "mux_ruby"

          MuxRuby.configure do |c|
            c.username = config.mux_token_id
            c.password = config.mux_token_secret
          end

          assets_api = MuxRuby::AssetsApi.new
          input_settings = MuxRuby::InputSettings.new(url: source_url)
          create_request = MuxRuby::CreateAssetRequest.new(
            input: [input_settings],
            playback_policy: [MuxRuby::PlaybackPolicy::PUBLIC]
          )

          response = assets_api.create_asset(create_request)
          asset = response.data

          video.update!(
            key: asset.id,
            playback_urls: { "hls" => "https://stream.mux.com/#{asset.playback_ids&.first&.id}.m3u8" }
          )

          Rails.logger.info("[helios-videos] Migration: video #{video.id} ingested into Mux: #{video.key}")
        end

        def ready?(video)
          return false unless video.key.present?

          require "mux_ruby"

          MuxRuby.configure do |c|
            c.username = config.mux_token_id
            c.password = config.mux_token_secret
          end

          assets_api = MuxRuby::AssetsApi.new
          asset = assets_api.get_asset(video.key)
          asset.data.status == "ready"
        rescue => e
          Rails.logger.warn("[helios-videos] Migration: error checking Mux readiness for video #{video.id}: #{e.message}")
          false
        end

        def delete!(video)
          return unless video.key.present?

          require "mux_ruby"

          MuxRuby.configure do |c|
            c.username = config.mux_token_id
            c.password = config.mux_token_secret
          end

          assets_api = MuxRuby::AssetsApi.new
          assets_api.delete_asset(video.key)
          Rails.logger.info("[helios-videos] Mux asset #{video.key} deleted")
        rescue MuxRuby::ApiError => e
          Rails.logger.warn("[helios-videos] Failed to delete Mux asset #{video.key}: #{e.message}")
        end

        def playback_url(video, signed: false, expiration: 4.hours)
          return nil unless video.key.present?
          video.playback_urls&.dig("hls")
        end

        def player_component(video, muted: false, expiration: 4.hours)
          unless video.key.present? && extract_playback_id(video).present?
            return <<~HTML.html_safe
              <div class="text-center p-4 text-muted">
                <div class="spinner-border spinner-border-sm me-2" role="status"></div>
                Processing video...
              </div>
            HTML
          end

          playback_id = extract_playback_id(video)

          <<~HTML.html_safe
            <mux-player
              stream-type="on-demand"
              playback-id="#{playback_id}"
              controls
              #{"muted" if muted}
              style="width: 100%;"
            ></mux-player>
          HTML
        end

        def signed_token(video, expiration: 4.hours)
          nil # Mux uses playback IDs, not signed tokens in the same way
        end

        def download_url(video, expiration: 4.hours)
          return nil unless video.key.present?

          playback_id = extract_playback_id(video)
          return nil unless playback_id.present?

          # Mux provides static renditions at predictable URLs
          "https://stream.mux.com/#{playback_id}/high.mp4"
        end

        def download_thumbnail!(video, time: "3s")
          return false unless video.key.present?
          return true if video.thumbnail_image.attached?

          playback_id = extract_playback_id(video)
          return false unless playback_id.present?

          url = "https://image.mux.com/#{playback_id}/thumbnail.jpg?time=#{time.to_i}"

          require "open-uri"
          downloaded_image = URI.open(url)
          video.thumbnail_image.attach(
            io: downloaded_image,
            filename: "video_#{video.id}_thumbnail.jpg",
            content_type: "image/jpeg"
          )
          true
        rescue => e
          Rails.logger.error("[helios-videos] Failed to download Mux thumbnail for video #{video.id}: #{e.message}")
          false
        end

        private

        def extract_playback_id(video)
          hls_url = video.playback_urls&.dig("hls")
          return nil unless hls_url.present?
          # Extract from https://stream.mux.com/PLAYBACK_ID.m3u8
          hls_url.match(%r{stream\.mux\.com/([^.]+)\.m3u8})&.captures&.first
        end
      end
    end
  end
end
