struct SatelliteController
  include Controller

  def list
    query = <<-SQL
      SELECT catalog_number, name
      FROM satellites
      SQL

    passes = db.query_all(query) do |rs|
      {
        catalog_number: rs.read(Int32),
        name:           rs.read(String),
      }
    end

    response.content_type = "application/json"
    response.headers["Access-Control-Allow-Origin"] = "*"
    passes.to_json(response)
  end

  def realtime
    satellite_catnum = params["satellite"].to_i32
    tle = schedule_generator.tles.find { |tle| tle.catalog_number == satellite_catnum }
    raise "catalog number not found" unless tle
    satellite = Predict::Satellite.new(tle)

    qth = Predict::LatLongAlt.from_degrees(
      config.location.latitude,
      config.location.longitude,
      config.location.altitude
    )

    ws_upgrade do |ws|
      spawn do
        loop do
          now = Time.now
          satpos, vel = satellite.predict(now)

          look_angles = qth.look_at(satpos, now)
          lat_long_alt = satpos.to_lat_long_alt(now)

          data = {
            azimuth:   look_angles.azimuth / Predict::DEG2RAD,
            elevation: look_angles.elevation / Predict::DEG2RAD,
            latitude:  lat_long_alt.latitude / Predict::DEG2RAD,
            longitude: lat_long_alt.longitude / Predict::DEG2RAD,
            altitude:  lat_long_alt.altitude,
          }

          break if ws.closed?
          ws.send(data.to_json)
          sleep 500.milliseconds
        end
      end
    end
  end
end
