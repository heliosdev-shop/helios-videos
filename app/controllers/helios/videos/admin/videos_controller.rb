module Helios
  module Videos
    module Admin
      class VideosController < Helios::Videos::Admin::BaseController
        before_action :set_video

        def show
          render json: {
            id: @video.id,
            ready: @video.key.present? && @video.playback_urls.present?,
            player_html: @video.key.present? ? @video.player_component : nil
          }
        end

        def update
          if @video.update(video_params)
            head :ok
          else
            head :unprocessable_entity
          end
        end

        private

        def set_video
          @video = Helios::Videos.video_class.find(params[:id])
        end

        def video_params
          params.require(:video).permit(:name)
        end
      end
    end
  end
end
