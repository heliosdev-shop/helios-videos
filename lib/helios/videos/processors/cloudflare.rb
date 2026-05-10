require "net/http"
require "json"
require "jwt"

module Helios
  module Videos
    module Processors
      class Cloudflare < Processor
        SIGNING_KEY_CACHE_KEY = "helios_videos_cf_signing_key"
        SIGNING_KEY_ID_CACHE_KEY = "helios_videos_cf_signing_key_id"

        def ingest!(video)
          return if video.key.present?
          return unless video.video_file.attached?

          uri = URI("https://api.cloudflare.com/client/v4/accounts/#{account_id}/stream/copy")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri.request_uri, {
            "Authorization" => "Bearer #{api_token}",
            "Content-Type" => "application/json"
          })

          request.body = {
            url: video.video_file.url,
            meta: { name: video.name },
            requireSignedURLs: config.require_signed_urls
          }.to_json

          response = http.request(request)
          body = JSON.parse(response.body)

          unless response.is_a?(Net::HTTPSuccess)
            Rails.logger.error("[helios-videos] Cloudflare ingest error: #{response.code} - #{response.body}")
            raise "Cloudflare ingest failed: #{response.code}"
          end

          video.update!(
            key: body["result"]["uid"],
            playback_urls: body["result"]["playback"],
            requires_signed_urls: config.require_signed_urls
          )

          Rails.logger.info("[helios-videos] Video #{video.id} ingested into Cloudflare: #{video.key}")
        end

        def delete!(video)
          return unless video.key.present?

          uri = URI("https://api.cloudflare.com/client/v4/accounts/#{account_id}/stream/#{video.key}")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Delete.new(uri.request_uri, {
            "Authorization" => "Bearer #{api_token}",
            "Content-Type" => "application/json"
          })

          response = http.request(request)

          if response.is_a?(Net::HTTPSuccess)
            Rails.logger.info("[helios-videos] Cloudflare video #{video.key} deleted")
          else
            Rails.logger.warn("[helios-videos] Failed to delete Cloudflare video #{video.key}: #{response.code}")
          end
        end

        def playback_url(video, signed: false, expiration: 4.hours)
          return nil unless video.key.present?

          if signed || video.requires_signed_urls?
            token = signed_token(video, expiration: expiration)
            subdomain = customer_subdomain(video)
            "https://#{subdomain}.cloudflarestream.com/#{token}/manifest/video.m3u8"
          else
            video.playback_urls&.dig("hls")
          end
        end

        def player_component(video, muted: false, expiration: 4.hours)
          return "(VIDEO NOT AVAILABLE)" unless video.key.present?

          video_src = playback_url(video, signed: video.requires_signed_urls?, expiration: expiration)

          <<~HTML.html_safe
            <video
              id="videojs-#{video.key}"
              class="video-js vjs-default-skin"
              style="width: 100%; height: 100%;"
              controls
              preload="auto"
              data-setup='{}'
              #{"muted" if muted}
            >
              <source src="#{video_src}" type="application/x-mpegURL" />
              Your browser does not support HLS video.
            </video>
          HTML
        end

        def signed_token(video, expiration: 4.hours)
          key_id, private_key = fetch_signing_key

          now = Time.now.to_i
          payload = {
            sub: video.key,
            kid: key_id,
            exp: now + expiration.to_i,
            nbf: now - 60
          }

          JWT.encode(payload, private_key, "RS256", typ: "JWT", kid: key_id)
        end

        def download_thumbnail!(video, time: "3s")
          return false unless video.key.present?
          return true if video.thumbnail_image.attached?

          subdomain = customer_subdomain(video)
          return false unless subdomain.present?

          if video.requires_signed_urls?
            token = signed_token(video, expiration: 1.hour)
            base_url = "https://#{subdomain}.cloudflarestream.com/#{token}/thumbnails/thumbnail.jpg"
          else
            base_url = "https://#{subdomain}.cloudflarestream.com/#{video.key}/thumbnails/thumbnail.jpg"
          end
          url = time.present? ? "#{base_url}?time=#{time}" : base_url

          require "open-uri"
          downloaded_image = URI.open(url)
          video.thumbnail_image.attach(
            io: downloaded_image,
            filename: "video_#{video.id}_thumbnail.jpg",
            content_type: "image/jpeg"
          )
          Rails.logger.info("[helios-videos] Downloaded thumbnail for video #{video.id}")
          true
        rescue => e
          Rails.logger.error("[helios-videos] Failed to download thumbnail for video #{video.id}: #{e.message}")
          false
        end

        private

        def account_id
          config.cloudflare_account_id || raise("CLOUDFLARE_ACCOUNT_ID not configured")
        end

        def api_token
          config.cloudflare_api_token || raise("CLOUDFLARE_API_TOKEN not configured")
        end

        def customer_subdomain(video)
          config.cloudflare_customer_subdomain || extract_subdomain_from_video(video)
        end

        def extract_subdomain_from_video(video)
          return nil unless video.playback_urls.present? && video.playback_urls["hls"].present?
          uri = URI.parse(video.playback_urls["hls"])
          uri.host.split(".").first
        rescue => e
          Rails.logger.error("[helios-videos] Failed to extract subdomain: #{e.message}")
          nil
        end

        def fetch_signing_key
          cached_key = Rails.cache.read(SIGNING_KEY_CACHE_KEY)
          cached_key_id = Rails.cache.read(SIGNING_KEY_ID_CACHE_KEY)

          if cached_key.present? && cached_key_id.present?
            begin
              return [cached_key_id, OpenSSL::PKey::RSA.new(cached_key)]
            rescue OpenSSL::PKey::RSAError
              Rails.cache.delete(SIGNING_KEY_CACHE_KEY)
              Rails.cache.delete(SIGNING_KEY_ID_CACHE_KEY)
            end
          end

          result = create_signing_key
          key_id = result["id"]
          pem = Base64.decode64(result["pem"])

          Rails.cache.write(SIGNING_KEY_CACHE_KEY, pem, expires_in: 7.days)
          Rails.cache.write(SIGNING_KEY_ID_CACHE_KEY, key_id, expires_in: 7.days)

          [key_id, OpenSSL::PKey::RSA.new(pem)]
        end

        def create_signing_key
          uri = URI("https://api.cloudflare.com/client/v4/accounts/#{account_id}/stream/keys")
          http = Net::HTTP.new(uri.host, uri.port)
          http.use_ssl = true

          request = Net::HTTP::Post.new(uri.request_uri, {
            "Authorization" => "Bearer #{api_token}",
            "Content-Type" => "application/json"
          })

          response = http.request(request)
          body = JSON.parse(response.body)

          unless response.is_a?(Net::HTTPSuccess)
            raise "Failed to create Cloudflare signing key: #{response.code} - #{response.body}"
          end

          body["result"] || raise("Cloudflare API returned no result: #{body.inspect}")
        end
      end
    end
  end
end
