module Helios
  module Videos
    class Engine < ::Rails::Engine
      isolate_namespace Helios::Videos

      # When helios-press is also loaded, mix video support into Block
      initializer "helios_videos.integrate_with_press" do
        ActiveSupport.on_load(:active_record) do
          if defined?(Helios::Press::Block)
            Helios::Press::Block.class_eval do
              has_one :video, class_name: "Helios::Videos::Video", foreign_key: :block_id, dependent: :destroy
            end
          end
        end
      end
    end
  end
end
