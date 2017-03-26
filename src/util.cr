require "digest/sha1"

module Util
  def self.time(name)
    t1 = Time.now
    yield
    dt = Time.now - t1

    puts "#{name}: #{dt.total_seconds * 1000}ms"
  end
end

module Controller
  def initialize(@context, @params, @db, @config, @schedule_generator, @web_server)
  end

  getter context : HTTP::Server::Context
  getter params : Hash(String, String)
  getter db : DB::Database
  getter config : Config
  getter schedule_generator : ScheduleGenerator
  getter web_server : WebServer

  def request
    context.request
  end

  def response
    context.response
  end

  def ws_upgrade
    if request.headers["Upgrade"]? == "websocket" &&
       request.headers.includes_word?("Connection", "Upgrade")
      key = request.headers["Sec-Websocket-Key"]
      accept_code = Digest::SHA1.base64digest("#{key}258EAFA5-E914-47DA-95CA-C5AB0DC85B11")

      response.status_code = 101
      response.headers["Upgrade"] = "websocket"
      response.headers["Connection"] = "Upgrade"
      response.headers["Sec-Websocket-Accept"] = accept_code
      response.upgrade do |io|
        ws = HTTP::WebSocket.new(io)
        yield ws
        ws.run
        io.close
      end
    end
  end
end
