require "json"

class Config
  JSON.mapping(
    location: Location,
    http_port: Int32,
    database_url: String,
    storage_dir: String,
    space_track_credentials: SpaceTrackCredentials,
    satellite_catnums: Array(Int32)
  )

  class SpaceTrackCredentials
    JSON.mapping(
      username: String,
      password: String
    )
  end

  class Location
    JSON.mapping(
      latitude: Float64,
      longitude: Float64,
      altitude: Float64
    )
  end
end
