struct FileController
  include Controller

  def serve
    filename = params["filename"]
    file_path = File.join(config.storage_dir, filename)

    File.open(file_path) do |file|
      IO.copy(file, response)
    end
  end

  def upload
    pass_id = nil
    file_name = nil
    HTTP::FormData.parse(request) do |part|
      case part.name
      when "pass_id" then pass_id = part.body.gets_to_end
      when "data"
        file_name = SecureRandom.hex + ".wav"
        file_path = File.join(config.storage_dir, file_name)
        File.open(file_path, "w") do |file|
          IO.copy(part.body, file)
        end
      end
    end

    return response.respond_with_error("No pass_id") unless pass_id
    return response.respond_with_error("No data") unless file_name

    sql = <<-SQL
      INSERT INTO files (pass_id, type, filename) VALUES ($1, $2, $3)
      SQL
    db.exec(sql, pass_id, PassProcessor::FileTypes::Audio.to_i16, file_name)

    web_server.pass_complete.emit(pass_id)
  end
end
