require "pg"
require "cute"
require "./src/**"

config = File.open(ARGV[0], "r") do |file|
  Config.from_json(file)
end

DB.open(config.database_url) do |db|
  schedule_generator = ScheduleGenerator.new(config, db)
  # pass_processor = PassProcessor.new(config, db)
  web_server = WebServer.new(config, db)

  web_server.manual_schedule_update.on(&->schedule_generator.update_schedule)
  # web_server.pass_complete.on(&->pass_processor.update)
  sleep
end
