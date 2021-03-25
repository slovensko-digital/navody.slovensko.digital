class DatahubRecord < ActiveRecord::Base
  self.abstract_class = true

  connects_to database: { writing: :datahub, reading: :datahub }
end
