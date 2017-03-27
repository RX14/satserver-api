require "http"
require "radix"
require "cute"

class WebServer
  alias Route = HTTP::Server::Context, Hash(String, String) -> Nil

  def initialize(@config : Config, @db : DB::Database, @schedule_generator : ScheduleGenerator)
    @tree = Radix::Tree(Route).new
    draw_routes

    spawn { run }
  end

  Cute.signal manual_schedule_update
  Cute.signal pass_complete(pass_id : String)

  private def draw_routes
    route "GET", "/api/v1/satellites", SatelliteController.list
    route "GET", "/api/v1/satellites/:satellite/realtime", SatelliteController.realtime

    route "GET", "/api/v1/passes", PassController.list
    route "GET", "/api/v1/passes/upcoming", PassController.list_upcoming
    route "GET", "/api/v1/passes/collected", PassController.list_collected

    route "GET", "/api/v1/passes/:pass", PassController.show
    route "GET", "/api/v1/passes/:pass/files", PassController.files

    route "GET", "/api/v1/files/:filename", FileController.serve
    route "PUT", "/api/v1/files", FileController.upload

    route "POST", "/api/v1/login", UserController.login
    route "POST", "/api/v1/logout", UserController.logout
    route "POST", "/api/v1/register", UserController.register
  end

  private def run
    handlers = [
      HTTP::ErrorHandler.new,
      HTTP::LogHandler.new,
      # HTTP::CompressHandler.new,
    ]
    server = HTTP::Server.new("0.0.0.0", 8080, handlers) do |context|
      result = @tree.find("/#{context.request.method}#{context.request.path}")

      if result.found?
        result.payload.call(context, result.params)
      else
        context.response.status_code = 404
        context.response.content_type = "text/plain"
        context.response.puts "Not Found"
      end
    end

    puts "Listening on http://0.0.0.0:8080/"
    server.listen
  end

  private def route(method, path, &route : Route)
    @tree.add "/#{method}#{path}", route
  end

  private macro route(method, path, location)
    route({{method}}, {{path}}) do |context, params|
      %controller = {{location.receiver}}.new(context, params, @db, @config, @schedule_generator, self)
      %controller.{{location.name}}
    end
  end
end
