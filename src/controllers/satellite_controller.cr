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
end
