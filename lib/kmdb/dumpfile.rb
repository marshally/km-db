require 'kmdb/custom_record'

module KMDB
  class Dumpfile < ActiveRecord::Base
    include CustomRecord
    self.table_name = "dumpfiles"

    validates_presence_of :offset
    validates_presence_of :path

    def set(offset)
      update_attributes!(:offset => offset)
    end

    def offset
      attributes['offset'] || 0
    end

    def self.get(pathname, job = nil)
      self.table_name = "dumpfiles"
      job ||= 'nil'

      KMDB::Dumpfile.find_or_create_by_path_and_job(pathname.cleanpath.to_s, job)
    end
  end
end
