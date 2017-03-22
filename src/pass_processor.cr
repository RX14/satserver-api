class PassProcessor
  def initialize(@config : Config, @db : DB::Database)
  end

  def update(pass_id : String)
    spawn do
      query = <<-SQL
        SELECT filename
        FROM files
        WHERE pass_id = $1
          AND type = $2
        SQL
      audio_filename = @db.query_one?(query, pass_id, FileTypes::Audio.to_i16, as: String)
      raise "No raw file for pass with id #{pass_id}" unless audio_filename

      audio_path = File.join(@config.storage_dir, audio_filename)

      ENHANCEMENTS.each do |enhancement|
        file_name = SecureRandom.hex + ".png"
        file_path = File.join(@config.storage_dir, file_name)
        processing_log = wxtoimg(
          in: audio_path,
          out: file_path,
          direction: PassDirection::Northbound, # TODO: fix this
          enhancement: enhancement
        )

        @db.exec("INSERT INTO files (pass_id, type, filename, processing_log) VALUES ($1, $2, $3, $4)", pass_id, enhancement.to_i16, file_name, processing_log)
      end
    end
  end

  private def wxtoimg(*, in input_file, out output_file, direction : PassDirection, enhancement : FileTypes)
    args = Array(String).new

    args << "-v" # Verbose
    args << "-A" # Do not cut top and bottom

    case direction
    when PassDirection::Northbound
      args << "-N"
    when PassDirection::Southbound
      args << "-S"
    end

    if enhancement_code = enhancement.wxtoimg_code
      args << "-e" << enhancement_code
    end

    args << input_file
    args << output_file

    output_io = IO::Memory.new
    status = Process.run("/usr/bin/wxtoimg", args, output: output_io, error: output_io)
    output = output_io.to_s

    raise "wxtoimg failure" unless status.exit_code == 0

    output
  end

  enum FileTypes : Int16
    Audio
    Raw
    MCIR
    Sea
    Therm

    def wxtoimg_code
      case self
      when Raw
        nil
      when MCIR
        "MCIR"
      when Sea
        "sea"
      when Therm
        "therm"
      else
        raise "BUG: no wxtoimg_code available"
      end
    end
  end

  ENHANCEMENTS = FileTypes.values.tap(&.delete(FileTypes::Audio))

  enum PassDirection
    Northbound
    Southbound
  end
end
