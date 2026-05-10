module Helios
  module Videos
    class Configuration
      attr_accessor :processor,
                    :require_signed_urls,
                    :admin_parent_controller,
                    # Cloudflare
                    :cloudflare_account_id,
                    :cloudflare_api_token,
                    :cloudflare_customer_subdomain,
                    # Mux
                    :mux_token_id,
                    :mux_token_secret

      def initialize
        @processor = :cloudflare
        @require_signed_urls = true
        @admin_parent_controller = "ApplicationController"
        @cloudflare_account_id = ENV["CLOUDFLARE_ACCOUNT_ID"]
        @cloudflare_api_token = ENV["CLOUDFLARE_API_TOKEN"]
        @cloudflare_customer_subdomain = ENV["CLOUDFLARE_CUSTOMER_SUBDOMAIN"]
        @mux_token_id = ENV["MUX_TOKEN_ID"]
        @mux_token_secret = ENV["MUX_TOKEN_SECRET"]
      end
    end
  end
end
