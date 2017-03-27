struct PassController
  include Controller

  def list(where condition = "true")
    query = <<-SQL
      SELECT id, satellite_catnum, satellite.name, start_time, end_time, max_elevation,
             (SELECT count(*) FROM files WHERE pass_id = pass.id) AS file_count
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
        file_count:    rs.read(Int64),
      }
    end

    response.content_type = "application/json"
    response.headers["Access-Control-Allow-Origin"] = "*"
    passes.to_json(response)
  end

  def list_upcoming
    list where: "pass.start_time > now()"
  end

  def list_collected
    list where: "(SELECT count(*) FROM files WHERE pass_id = pass.id) > 1"
  end

  def show
    query = <<-SQL
      SELECT id, satellite_catnum, satellite.name, start_time, end_time, max_elevation
      FROM passes AS pass
      JOIN satellites AS satellite
        ON satellite.catalog_number = pass.satellite_catnum
      WHERE id = $1
      SQL

    pass_id = params["pass"]
    pass = db.query_one(query, pass_id) do |rs|
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
    pass.to_json(response)
  end

  def files
    query = <<-SQL
      SELECT pass_id, type, filename, processing_log
      FROM files AS file
      WHERE pass_id = $1
      SQL

    pass_id = params["pass"]
    passes = db.query_all(query, pass_id) do |rs|
      {
        pass: {
          id: rs.read(String),
        },
        type:           rs.read(Int16),
        url:            "/api/v1/files/#{rs.read(String)}",
        processing_log: rs.read(String?),
      }
    end

    response.content_type = "application/json"
    response.headers["Access-Control-Allow-Origin"] = "*"
    passes.to_json(response)
  end

  def update_tles
    return response.respond_with_error("Not Logged In", 401) unless check_token
    schedule_generator.update_schedule(force: true)
  end
end
