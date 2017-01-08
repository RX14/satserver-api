module Util
  def self.time(name)
    t1 = Time.now
    yield
    dt = Time.now - t1

    puts "#{name}: #{dt.total_seconds * 1000}ms"
  end
end

module Controller
  def initialize(@context, @params, @db)
  end

  getter context : HTTP::Server::Context
  getter params : Hash(String, String)
  getter db : DB::Database

  def request
    context.request
  end

  def response
    context.response
  end
end
