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

**Prerequisites:**
- ActiveStorage must be installed in your host app (`bin/rails active_storage:install`)
- Add the Ruby gem for your chosen video processor to your **host app's Gemfile**:
  - **Mux**: `gem "mux_ruby"`
  - **Cloudflare**: no additional gem needed (uses HTTP API directly)

## Configuration

Create `config/initializers/helios_videos.rb`:

```ruby
Helios::Videos.configure do |config|
  # Choose your video processor
  config.processor = :cloudflare  # or :mux

  # Parent controller for admin views (must provide authentication)
  config.admin_parent_controller = "Admin::BaseController"

  # Use an existing model instead of Helios::Videos::Video (optional)
  # Your model must include Helios::Videos::VideoConcern
  # and have the required columns: key, playback_urls (jsonb),
  # requires_signed_urls (boolean), provider (string)
  config.video_model = "Video"  # default: "Helios::Videos::Video"

  # Cloudflare Stream settings
  config.cloudflare_account_id = ENV["CLOUDFLARE_ACCOUNT_ID"]
  config.cloudflare_api_token  = ENV["CLOUDFLARE_API_TOKEN"]
  config.cloudflare_customer_subdomain = ENV["CLOUDFLARE_CUSTOMER_SUBDOMAIN"]
  config.require_signed_urls   = true

  # OR Mux settings
  # config.processor        = :mux
  # config.mux_token_id     = ENV["MUX_TOKEN_ID"]
  # config.mux_token_secret = ENV["MUX_TOKEN_SECRET"]
end
```

## Using an existing model

If your app already has a Video model, you can include the gem's functionality via a concern instead of using `Helios::Videos::Video`:

1. Add the required columns to your existing table:

```ruby
add_column :videos, :key, :string           # service identifier (Mux asset ID or Cloudflare UID)
add_column :videos, :playback_urls, :jsonb
add_column :videos, :requires_signed_urls, :boolean, default: false, null: false
add_column :videos, :provider, :string       # "cloudflare" or "mux"
```

2. Include the concern in your model:

```ruby
class Video < ApplicationRecord
  include Helios::Videos::VideoConcern
end
```

3. Set the model name in the initializer:

```ruby
config.video_model = "Video"
```

The concern adds: `video_file` and `thumbnail_image` ActiveStorage attachments, `provider` enum, automatic ingestion via background job on create, per-video processor routing, signed URL support, and thumbnail downloads.

### Upgrading from pre-0.2.0 (adding the provider column)

If you installed helios-videos before the `provider` column was added, you need to add it to your existing table. For apps using the gem's own table:

```bash
bin/rails helios_videos:install:migrations
bin/rails db:migrate
```

For apps using a custom video model with their own table, create a migration:

```ruby
class AddProviderToVideos < ActiveRecord::Migration[8.0]
  def change
    add_column :videos, :provider, :string
    add_index :videos, :provider

    # Backfill existing videos with their current provider
    reversible do |dir|
      dir.up do
        Video.where(provider: nil).update_all(provider: 'cloudflare') # or 'mux'
      end
    end
  end
end
```

## Routes

Mount the engine:

```ruby
mount Helios::Videos::Engine, at: "/videos"
```

## Usage

### Creating a video

```ruby
video = Helios::Videos.video_class.new(name: "My Video")
video.video_file.attach(params[:video_file])
video.save!
# CheckVideoJob will automatically ingest the video into your configured processor
```

### Displaying a video

```erb
<%= video.player_component %>
```

Each video renders using the correct player for its `provider` — Cloudflare videos use video.js with HLS, Mux videos use the mux-player element. This means both providers can coexist in the same app during and after a migration.

### Programmatic access

```ruby
video.playback_url                      # unsigned HLS URL
video.playback_url(signed: true)        # signed URL (Cloudflare)
video.signed_url(expiration: 2.hours)   # shorthand
video.download_url                      # downloadable MP4 URL
video.download_and_store_thumbnail!     # fetch and attach thumbnail
video.check_for_processing!             # manually trigger ingestion
video.effective_processor               # the processor for this video's provider
```

### With helios-press

When both gems are loaded, video blocks are automatically available in the block editor. Videos can be dragged into block placeholders for direct upload and processing.

## Migrating between providers

helios-videos includes built-in tooling for migrating videos between Cloudflare Stream and Mux. Migration happens record-by-record in background jobs so long ingestions don't block each other.

### How it works

The migration pipeline has three stages:

1. **MigrateVideosJob** (orchestrator) — finds all videos on the source provider, enqueues a conversion job for each one.
2. **ConvertVideoJob** (per-video) — gets a download URL from the source, submits it to the destination for ingestion.
   - For **Mux destinations**: playback IDs come back immediately, so the provider is flipped right away.
   - For **Cloudflare destinations**: processing takes time, so a check job is enqueued.
3. **CheckIngestionJob** (Cloudflare destination only) — polls Cloudflare every 30 seconds until the video is ready, then flips the provider.

### Running a migration

Make sure both providers are configured in your initializer (you need credentials for both), then enqueue the orchestrator:

```ruby
# Migrate all Cloudflare videos to Mux
Helios::Videos::Migration::MigrateVideosJob.perform_later(
  from: "cloudflare",
  to: "mux"
)

# Or migrate in batches
Helios::Videos::Migration::MigrateVideosJob.perform_later(
  from: "cloudflare",
  to: "mux",
  batch_size: 10
)
```

During migration, both providers are served concurrently — each video's `provider` column determines which processor handles playback. Videos that haven't been migrated yet continue to work on the original provider.

### Migrate a single video

```ruby
Helios::Videos::Migration::ConvertVideoJob.perform_later(
  video_id: 42,
  from: "cloudflare",
  to: "mux"
)
```

## JavaScript Setup

Your host app must import the Stimulus controller and the video player library for your chosen processor.

### Mux

```javascript
import '@mux/mux-player'  // Required — registers the <mux-player> custom element

import { HeliosVideoBlockController } from "helios/videos"
application.register("helios-video-block", HeliosVideoBlockController)
```

**npm dependency** (add to your host app's `package.json`):

```bash
yarn add @mux/mux-player
```

### Cloudflare

```javascript
import { HeliosVideoBlockController } from "helios/videos"
application.register("helios-video-block", HeliosVideoBlockController)
```

No additional npm packages are needed for Cloudflare — it uses a standard `<video>` element with HLS.

### Vite

If your host app uses Vite, add an alias so Vite can resolve the gem's JavaScript:

```typescript
// vite.config.mts
resolve: {
  alias: {
    'helios/videos': resolve(__dirname, '/path/to/helios-videos/app/javascript/helios/videos'),
  },
},
```

## License

Proprietary. All rights reserved.
