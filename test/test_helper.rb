require "bundler/setup"
Bundler.require(:default)
require "minitest/autorun"
require "minitest/pride"
require "active_record"
require "active_job"

ActiveJob::Base.logger.level = Logger::WARN

# to debug
if ENV["VERBOSE"]
  logger = ActiveSupport::Logger.new(STDOUT)
  ActiveRecord::Base.logger = logger
  # Makara::Logging::Logger.logger = logger
end

def adapter
  ENV["ADAPTER"] || "postgresql"
end

ActiveRecord::Base.establish_connection(
  adapter: "#{adapter}_makara",
  makara: {
    sticky: true,
    connections: [
      {
        role: "master",
        name: "primary",
        database: "distribute_reads_test_primary"
      },
      {
        name: "replica",
        database: "distribute_reads_test_replica"
      }
    ]
  }
)

ActiveRecord::Migration.create_table :users, force: true do |t|
  t.string :name
end

class User < ActiveRecord::Base
end

class TestJob < ActiveJob::Base
  distribute_reads

  def perform
    $current_database = current_database
  end
end

class ReadWriteJob < ActiveJob::Base
  def perform
    $current_database = current_database
    insert_value
  end
end

def insert_value
  User.create!(name: "Boom")
end

def current_database(prefix: nil)
  func = adapter == "mysql2" ? "database" : "current_database"
  ActiveRecord::Base.connection.exec_query("#{prefix}SELECT #{func}()").rows.first.first.split("_").last
end
