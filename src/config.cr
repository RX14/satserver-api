require "json"

class Config
  JSON.mapping(
    location: Location,
    http_port: Int32,
    database_url: String,
    tle_file: String
  )

  class Location
    JSON.mapping(
      latitude: Float64,
      longitude: Float64,
      altitude: Float64
    )
  end
end
