require 'cora'
require 'siri_objects'
require 'pp'
require 'lightwaverf'

#######
# This is a SiriProxy Plugin For LightWaveRF. It simply intercepts the phrases to
# control LightWaveRF devices and responds with a message about the command that
# is sent to the LightWaveRF gem.
######

class SiriProxy::Plugin::Lwrf < SiriProxy::Plugin

  def initialize(config)
    # get custom configuration options
  end

  #get the user's location and display it in the logs
  #filters are still in their early stages. Their interface may be modified
  filter "SetRequestOrigin", direction: :from_iphone do |object|
    puts "[Info - User Location] lat: #{object["properties"]["latitude"]}, long: #{object["properties"]["longitude"]}"

    #Note about returns from filters:
    # - Return false to stop the object from being forwarded
    # - Return a Hash to substitute or update the object
    # - Return nil (or anything not a Hash or false) to have the object forwarded (along with any
    #    modifications made to it)
  end

  # Test Commands
  listen_for /test lightwave/i do
    say "LightWave is in my control using the following config file: #{LightWaveRF.new.get_config_file}", spoken: "LightWave is in my control!"
    request_completed
  end

  # Commands to turn on/off a device in a room
  listen_for (/turn (on|off) the (.*) in the (#{Regexp.union(LightWaveRF.new.get_config["room"].keys.map(&:to_s))})/i) { |action, deviceName, roomName| send_lwrf_command(roomName,deviceName,action) }
  listen_for (/turn (on|off) the (#{Regexp.union(LightWaveRF.new.get_config["room"].keys.map(&:to_s))}) (.*)/i) { |action, roomName, deviceName| send_lwrf_command(roomName,deviceName,action) }
  listen_for (/turn the (.*) in the (#{Regexp.union(LightWaveRF.new.get_config["room"].keys.map(&:to_s))}) (on|off)/i) { |deviceName, roomName, action| send_lwrf_command(roomName,deviceName,action) }
  listen_for (/turn the (#{Regexp.union(LightWaveRF.new.get_config["room"].keys.map(&:to_s))}) (.*) (on|off)/i) { |roomName, deviceName, action| send_lwrf_command(roomName,deviceName,action) }

  # Commands to dim a devices in a room
  listen_for (/(?:(?:dim)|(?:set)|(?:turn up)|(?:turn down)|(?:set level on)|(?:set the level on)) the (.*) in the (#{Regexp.union(LightWaveRF.new.get_config["room"].keys.map(&:to_s))}) to ([1-9][0-9]?)(?:%| percent)?/i) { |deviceName, roomName, action| send_lwrf_command(roomName,deviceName,action) }
  listen_for (/(?:(?:dim)|(?:set)|(?:turn up)|(?:turn down)|(?:set level on)|(?:set the level on)) the (#{Regexp.union(LightWaveRF.new.get_config["room"].keys.map(&:to_s))}) (.*) to ([1-9][0-9]?)(?:%| percent)?/i) { |roomName, deviceName, action| send_lwrf_command(roomName,deviceName,action) }

  def send_lwrf_command (roomName, deviceName, action)  
    Thread.new {
      begin
        # initialise LightWaveRF Gem
        lwrf = LightWaveRF.new
        lwrfConfig = lwrf.get_config

        # Validate Inputs
        if lwrfConfig.has_key?("room") && lwrfConfig["room"].has_key?(roomName) && lwrfConfig["room"][roomName].include?(deviceName)
          say "Turning #{action} the #{deviceName} in the #{roomName}."
          lwrf.send "#{roomName}", "#{deviceName}", "#{action}"

        elsif lwrfConfig["room"].has_key?(roomName) 
          say "I'm sorry, I can't find '#{deviceName}' in the '#{roomName}'."

        elsif lwrfConfig.has_key?("room") 
          say "I'm sorry, I can't find '#{roomName}'."

        else    
          say "I'm sorry, I can't find either '#{roomName}' or '#{deviceName}'!"
        end

      rescue Exception
        pp $!
        say "Sorry, I encountered an error: #{$!}"
      ensure
        request_completed
      end
      }
  end

end
