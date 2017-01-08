require "predict"
require "json"
require "msgpack"

class ScheduleGenerator
  def initialize(@config : Config, @db : DB::Database)
    @tles = Array(Predict::TLE).new
    @schedule = Array(Pass).new
    @wait_channel = Channel(Nil).new

    spawn { run }
    update_schedule
  end

  def update_schedule
    @wait_channel.send nil
  end

  private def run
    loop do
      @wait_channel.receive

      update_tles
      generate_schedule
      send_schedule
    end
  rescue ex
    ex.inspect_with_backtrace(STDERR)
    exit(10)
  end

  private def update_tles
    tles = Array(Predict::TLE).new

    File.open(@config.tle_file, "r") do |file|
      while tle = Predict::TLE.parse_three_line(file)
        tles << tle
      end
    end

    @tles = tles
    update_satellites
  end

  private def generate_schedule
    start_time = Time.now
    end_time = start_time + 48.hours

    location = Predict::LatLongAlt.from_degrees(
      @config.location.latitude,
      @config.location.longitude,
      @config.location.altitude
    )
    schedule = Array(Pass).new

    @tles.each do |tle|
      sat = Predict::Satellite.new(tle)

      time = start_time
      while time < end_time
        pass_start, pass_end = sat.next_pass(at: location, after: time)
        time = pass_end

        schedule << Pass.new(sat, location, pass_start, pass_end)
      end
    end

    schedule.sort! { |a, b| a.start_time <=> b.start_time }
    schedule.reject! { |pass| pass.max_elevation < 15.0 }

    last_pass = nil
    schedule.reject! do |pass|
      unless last_pass
        last_pass = pass
        next
      end

      if pass.start_time < last_pass.end_time
        # if pass.end_time < last_pass.end_time
        #   # `pass` is contained entirely within `last_pass`
        #   next true
        # end

        # TODO: better heuristics
        next true
      end

      last_pass = pass

      false
    end

    @schedule = schedule
  end

  private def send_schedule
    @schedule.each do |pass|
      query = <<-SQL
        INSERT INTO passes
        (satellite_catnum, start_time, end_time, max_elevation) VALUES ($1, $2, $3, $4)
        ON CONFLICT (satellite_catnum, seconds(start_time))
          DO UPDATE SET start_time = $2, end_time = $3, max_elevation = $4
        SQL
      @db.exec query, pass.satellite_catnum, pass.start_time, pass.end_time, pass.max_elevation
    end
  end

  # Update satellite table in the DB
  private def update_satellites
    @tles.each do |tle|
      query = <<-SQL
        INSERT INTO satellites
        (catalog_number, name) VALUES ($1, $2)
        ON CONFLICT (catalog_number) DO UPDATE SET name = $2
        SQL
      @db.exec query, tle.catalog_number, tle.name
    end
  end

  class Pass
    MessagePack.mapping({
      satellite_catnum: Int32,
      start_time:       {type: Time, converter: CrystalTimeConverter},
      end_time:         {type: Time, converter: CrystalTimeConverter},
      max_elevation:    Float32,
      look_angles:      Array({Float32, Float32}),
    })

    # DB.mapping({
    #   satellite_catnum: Int32,
    #   start_time:       Time,
    #   end_time:         Time,
    #   max_elevation:    Float32,
    # })

    @look_angles = [] of {Float32, Float32}

    def initialize(@satellite_catnum : Int32, @start_time : Time, @end_time : Time,
                   @max_elevation : Float32, @look_angles : Array({Float32, Float32}))
    end

    def self.new(satellite, location, start_time, end_time)
      pass_length = end_time - start_time
      # TODO: https://github.com/crystal-lang/crystal/pull/3749
      look_angles = Array({Float32, Float32}).new((pass_length.ticks / 1.second.ticks) + 2)

      time = start_time
      max_elevation = 0.0f32
      while time < end_time
        position, _ = satellite.predict(time)
        look_angle = location.look_at(position, time)

        azimuth_degrees = look_angle.azimuth / Predict::DEG2RAD
        elevation_degrees = look_angle.elevation / Predict::DEG2RAD
        look_angles << {azimuth_degrees.to_f32, elevation_degrees.to_f32}

        max_elevation = {max_elevation, elevation_degrees.to_f32}.max

        time += 1.second
      end

      new(satellite.tle.catalog_number, start_time, end_time, max_elevation, look_angles)
    end

    def pretty_print(pp) : Nil
      prefix = "#<ScheduleGenerator::Pass:0x#{object_id.to_s(16)}"
      executed = exec_recursive(:pretty_print) do
        pp.surround(prefix, ">", left_break: " ", right_break: nil) do
          pp.group do
            pp.text "@start_time="
            @start_time.pretty_print(pp)
          end
          pp.comma
          pp.group do
            pp.text "@end_time="
            @end_time.pretty_print(pp)
          end
          pp.comma
          pp.group do
            pp.text "@max_elevation="
            @max_elevation.pretty_print(pp)
          end
          pp.comma
          pp.group do
            pp.text "@look_angles="
            pp.text "#{@look_angles.size} items"
          end
        end
      end

      unless executed
        pp.text "#{prefix} ...>"
      end
    end
  end

  private module CrystalTimeConverter
    def self.to_msgpack(time : Time, packer : MessagePack::Packer)
      packer.write(time.@encoded)
    end

    def self.from_msgpack(unpacker : MessagePack::Unpacker)
      encoded = packer.read_int
      ticks = encoded & Time::TicksMask
      kind = Time::Kind.new((encoded.to_u64 >> Time::KindShift).to_i64)
      Time.new(ticks, kind: kind)
    end
  end
end
