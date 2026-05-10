module Helios
  module Videos
    class ApplicationRecord < ActiveRecord::Base
      self.abstract_class = true
    end
  end
end
