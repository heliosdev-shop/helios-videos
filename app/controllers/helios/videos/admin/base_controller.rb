module Helios
  module Videos
    module Admin
      class BaseController < Helios::Videos.configuration.admin_parent_controller.constantize
      end
    end
  end
end
