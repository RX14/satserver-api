struct PassController
  include Controller

  def list(where condition = "true")
    query = <<-SQL
      SELECT id, satellite_catnum, satellite.name, start_time, end_time, max_elevation
      FROM passes AS pass
      JOIN satellites AS satellite
        ON satellite.catalog_number = pass.satellite_catnum
      WHERE #{condition}
      SQL

    passes = db.query_all(query) do |rs|
      {
        id:        rs.read(String),
        satellite: {
          catalog_number: rs.read(Int32),
          name:           rs.read(String),
        },
        start_time:    rs.read(Time),
        end_time:      rs.read(Time),
        max_elevation: rs.read(Float32),
      }
    end

    response.content_type = "application/json"
    response.headers["Access-Control-Allow-Origin"] = "*"
    passes.to_json(response)
  end

  def list_upcoming
    list where: "pass.start_time > now()"
  end
end
