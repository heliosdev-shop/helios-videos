module Helios
  module Videos
    class Video < ActiveRecord::Base
      self.table_name = "helios_videos_videos"

      include Helios::Videos::VideoConcern

      # Optional association to helios-press block (when both gems are loaded)
      if defined?(Helios::Press::Block)
        belongs_to :block, class_name: "Helios::Press::Block", optional: true
      end
    end
  end
end
