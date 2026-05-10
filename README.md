# Helios::Videos

Video upload, processing, and streaming for Rails. Upload videos via ActiveStorage direct upload to S3, ingest into Mux or Cloudflare Stream for processing, and serve streaming video.

## Installation

Add to your Gemfile:

```ruby
gem "helios-videos"
```

Then:

```bash
bundle install
bin/rails helios_videos:install:migrations
bin/rails db:migrate
```

**Prerequisites:** Your host app must have ActiveStorage installed (`bin/rails active_storage:install`).

## Configuration

Create `config/initializers/helios_videos.rb`:

```ruby
Helios::Videos.configure do |config|
  # Choose your video processor
  config.processor = :cloudflare  # or :mux

  # Cloudflare Stream settings
  config.cloudflare_account_id = ENV["CLOUDFLARE_ACCOUNT_ID"]
  config.cloudflare_api_token  = ENV["CLOUDFLARE_API_TOKEN"]
  config.require_signed_urls   = true

  # OR Mux settings
  # config.processor       = :mux
  # config.mux_token_id    = ENV["MUX_TOKEN_ID"]
  # config.mux_token_secret = ENV["MUX_TOKEN_SECRET"]
end
```

## Routes

Mount the engine:

```ruby
mount Helios::Videos::Engine, at: "/helios_videos"
```

## Usage

### Creating a video

```ruby
video = Helios::Videos::Video.new(name: "My Video")
video.video_file.attach(params[:video_file])
video.save!
# CheckVideoJob will automatically ingest the video into your configured processor
```

### Displaying a video

```erb
<%= video.player_component %>
```

### With helios-press

When both gems are loaded, video blocks are automatically available in the block editor. Videos can be dragged into block placeholders for direct upload and processing.

## JavaScript

Register the Stimulus controllers in your host app:

```javascript
import { HeliosVideoBlockController } from "helios-videos"
application.register("video-block", HeliosVideoBlockController)
```

## License

Proprietary. All rights reserved.
