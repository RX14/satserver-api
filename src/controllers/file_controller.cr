struct FileController
  include Controller

  def serve
    filename = params["filename"]
    file_path = File.join(config.storage_dir, filename)

    File.open(file_path) do |file|
      IO.copy(file, response)
    end
  end
end
