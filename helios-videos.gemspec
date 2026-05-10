require_relative "lib/helios/videos/version"

Gem::Specification.new do |spec|
  spec.name        = "helios-videos"
  spec.version     = Helios::Videos::VERSION
  spec.authors     = [ "Jason Fleetwood-Boldt" ]
  spec.email       = [ "jason@heliosflow.ai" ]
  spec.homepage    = "https://github.com/heliosdev/helios-videos"
  spec.summary     = "Video upload, processing, and streaming for Rails via Mux or Cloudflare Stream"
  spec.description = "Upload videos to S3 via ActiveStorage direct upload, ingest into Mux or Cloudflare Stream for processing, and serve streaming video back to users."
  spec.license     = "Nonstandard"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0"
  spec.add_dependency "jwt", ">= 2.0"
end
