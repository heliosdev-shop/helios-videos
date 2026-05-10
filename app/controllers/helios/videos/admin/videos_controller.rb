module Helios
  module Videos
    module Admin
      class VideosController < Helios::Videos::Admin::BaseController
        before_action :set_video

        def update
          if @video.update(video_params)
            head :ok
          else
            head :unprocessable_entity
          end
        end

        private

        def set_video
          @video = Video.find(params[:id])
        end

        def video_params
          params.require(:video).permit(:name)
        end
      end
    end
  end
end
