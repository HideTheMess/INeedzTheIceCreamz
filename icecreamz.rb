require 'nokogiri'
require 'rest-client'
require 'json'
require 'addressable/uri'

API_KEY = "API KEY HERE!!"

class Location
  attr_accessor :latitude, :logitude

  def initialize(lat, long)
    @latitude = lat
    @longitude = long
  end

  def coords
    [@latitude, @longitude]
  end

  def directions_to(other)
    directions_hash = {}

    url = Addressable::URI.new(
        :scheme => "http",
        :host   => "maps.googleapis.com",
        :path   => "/maps/api/directions/json",
        :query_values  => { :origin      => self.coords.join(","),
                            :destination => other.coords.join(","),
                            :sensor      => false,
                            :mode        => "walking"
                          }
        ).to_s

    json_string = RestClient.get(url)
    json        = JSON.parse(json_string)
    directions_hash[:distance] = json['routes'][0]['legs'][0]["distance"]["text"]
    directions_hash[:duration] = json['routes'][0]['legs'][0]["duration"]["text"]
    directions  = []

    json['routes'][0]['legs'][0]["steps"].each do |dir_hash|
      parsed_html = Nokogiri::HTML(dir_hash["html_instructions"])
      directions <<  parsed_html.text
    end

    directions_hash[:directions] = directions.join("\n")

    directions_hash
  end

  def nil?
    return true if @latitude.nil? || @longitude.nil?
    false
  end
end


class User
  attr_accessor :location

  # Factory method to create a new user Object
  def self.get_user_location
    # Get user location. Should be address or approximate City
    puts "What is your address? "
    address = gets.chomp
    lat, long = self.convert_address_to_lat_long(address)
    User.new(lat, long)
  end

  def self.convert_address_to_lat_long(address)
    url = Addressable::URI.new(
        :scheme => "http",
        :host   => "maps.googleapis.com",
        :path   => "/maps/api/geocode/json",
        :query_values  => { :address => address,
                            :sensor => false}
        ).to_s
    json_string = RestClient.get(url)
    json        = JSON.parse(json_string)

    location_dict = json["results"][0]["geometry"]["location"]
    lat, long     = location_dict.values

    [lat, long]
  end

  def initialize(lat, long)
    @location = Location.new(lat, long)
  end

  def find_ice_cream_shops(radius=500)
    # Returns an array of Shops?
    coords = self.location.coords

    url = Addressable::URI.new(
    :scheme => "https",
    :host   => "maps.googleapis.com",
    :path   => "/maps/api/place/nearbysearch/json",
    :query_values  => {
                        :key      => API_KEY,
                        :location => coords.join(","),
                        :radius   => radius,
                        :sensor   => false,
                        :type     => "food",
                        :keyword  => "ice cream"
                      }
    ).to_s

    json_string = RestClient.get(url)
    json        = JSON.parse(json_string)

    status = json["status"]
    raise "no results found in radius" if status == "ZERO_RESULTS"
    shops = []

    json["results"].each do |shop_hash|
      shops << Shop.new(shop_hash)
    end

    shops
  end

  def directions_to(shop)
    # Calls the location object's own location method that takes in
    # another location object
    self.location.directions_to(shop.location)
  end

  def show_directions_to(shop)
    dirs     = self.directions_to(shop)
    distance = dirs[:distance]
    duration = dirs[:duration]
    directions = dirs[:directions]

    puts "You're going to get Ice Cream at #{shop.name}"
    puts "It is #{distance} away and about a #{duration} walk"
    puts "Here are your Directions!"
    puts directions
  end
end


class Shop
  attr_accessor :name, :location

  def initialize(options_hash)
    long       = options_hash["geometry"]["location"]["lng"]
    lat        = options_hash["geometry"]["location"]["lat"]
    @name      = options_hash["name"]
    @location  = Location.new(lat, long)
  end
end


if __FILE__==$PROGRAM_NAME

  u     = User.get_user_location
  shops = u.find_ice_cream_shops(500)
  shop  = shops.first
  u.show_directions_to(shop)

end