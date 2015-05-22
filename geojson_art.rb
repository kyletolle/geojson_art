require 'forwardable'
require 'bigdecimal'
require 'json'

class Point
  attr_accessor :latitude, :longitude

  # Expects strings as the coordinates
  def initialize(longitude, latitude)
    @longitude = BigDecimal.new(longitude)
    @latitude  = BigDecimal.new(latitude)
  end

  def shifted_longitude
    longitude - SHIFT_DECIMAL
  end

  def shifted_latitude
    latitude - SHIFT_DECIMAL
  end

  def as_json
    [ longitude.truncate(4).to_f, latitude.truncate(4).to_f ]
  end

  def to_s
    %([#{longitude_string},#{latitude_string}])
  end

private
  SHIFT_AMOUNT = "0.0001"
  SHIFT_DECIMAL = BigDecimal.new(SHIFT_AMOUNT)

  def longitude_string
    decimal_to_string(longitude)
  end

  def latitude_string
    decimal_to_string(latitude)
  end

  def decimal_to_string(decimal)
    decimal.truncate(4).to_s("F")
  end
end

original_point = Point.new("-104.945", "39.837")


class Block
  def initialize(starting_point)
    @starting_point = starting_point
  end

  def coordinates
    nw = @starting_point
    ne = Point.new(nw.shifted_longitude, nw.latitude)
    se = Point.new(nw.shifted_longitude, nw.shifted_latitude)
    sw = Point.new(nw.longitude, nw.shifted_latitude)

    [ nw, ne, se, sw, nw]
  end

  def as_json
    coordinates.map{|p| p.as_json}
  end

  def to_s
    %([#{coordinates.map{|point| point.to_s}.join(",")})
  end
end

block = Block.new(original_point)


class Geojson
end

class Geojson::Feature
  def initialize(block)
    @block = block
  end

  def coordinates
    @block.coordinates
  end

  def add_to(collection)
    collection << self
  end

  def geojson
    {
      type: "Feature",
      properties: {},
      geometry: {
        type: "Polygon",
        coordinates: [ @block.as_json ]
      }
    }
  end

  def to_s
    JSON.generate(geojson)
  end
end

feature = Geojson::Feature.new(block)


class Geojson::FeatureCollection
  extend Forwardable

  attr_accessor :features

  def initialize
    @features = []
  end

  def geojson
    {
      type: "FeatureCollection",
      features: @features.map{|feature| feature.geojson}
    }
  end

  def to_s
    JSON.generate(geojson)
  end

  def_delegators :@features, :<<
end


class GeojsonArt
  def generate
    @collection = Geojson::FeatureCollection.new

    original_point = Point.new("-104.945", "39.837")

    current_longitude = original_point.longitude
    line_latitude     = original_point.latitude

    File.foreach(ascii_art_file_path) do |line|
      line.each_char do |c|
        current_point = Point.new(current_longitude, line_latitude)
        should_draw_point = c =~ /\*/

        block = Block.new(current_point)
        feature = Geojson::Feature.new(block)

        feature.add_to(@collection) if should_draw_point

        current_longitude = current_point.shifted_longitude
      end

      current_longitude = original_point.longitude
      line_latitude = Point.new(current_longitude, line_latitude).shifted_latitude
    end

    write_geojson_file
  end

private
  def ascii_art_file_path
    "space_invader_side_by_side.txt"
  end

  def geojson_art_file_path
    "space_invader_side_by_side.geojson"
  end

  def write_geojson_file
    File.open(geojson_art_file_path, 'w') do |geojson|
      geojson.write @collection
    end
    puts "Wrote art to #{geojson_art_file_path}"
  end
end

GeojsonArt.new.generate

