=begin

  Base class for KM data.
  Connect to a secondary database to store events, users, & properties.

  FIXME: the database connection is hard-coded for now.

=end

require 'active_record'
require 'erb'
require 'yaml'
require 'kmdb/migration'


module KMDB
  module CustomRecord
    DefaultConfig = {
      'adapter'  => 'sqlite3',
      'database' => "test.db"
    }

    def self.disable_index
      connection.execute %Q{
        ALTER TABLE `#{table_name}` DISABLE KEYS;
      }
    end

    def self.enable_index
      connection.execute %Q{
        ALTER TABLE `#{table_name}` ENABLE KEYS;
      }
    end

    def self.connect_to_km_db!
      config = DefaultConfig.dup
      ['km_db.yml', 'config/km_db.yml'].each do |config_path|
        next unless File.exist?(config_path)
        config.merge! YAML.load(ERB.new(File.open(config_path).read).result)
        break
      end

      ActiveRecord::Base.establish_connection(config)

      unless ActiveRecord::Base.connection.table_exists?('events')
        SetupEventsDatabase.up
        # reset_column_information
      end
    end
  end
end
