class AddProviderToHeliosVideosVideos < ActiveRecord::Migration[8.0]
  def change
    unless column_exists?(:helios_videos_videos, :provider)
      add_column :helios_videos_videos, :provider, :string
      add_index :helios_videos_videos, :provider
    end
  end
end
