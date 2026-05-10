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
          create_request = MuxRuby::CreateAssetRequest.new(
            input: video.video_file.url,
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
          return "(VIDEO NOT AVAILABLE)" unless video.key.present?

          playback_id = extract_playback_id(video)
          return "(VIDEO NOT AVAILABLE)" unless playback_id.present?

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
