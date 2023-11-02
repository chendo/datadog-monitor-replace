# Datadog Monitor Replace
# 
# This script lets you perform a find and replace of all monitor message text, so you can rename alerting channels
# Requires `monitors_read`, `monitors_write`, `synthetics_read`, `synthetics_write`, `synthetics_private_location_read`
# 
# This script is MIT-licensed, use at your own risk etc.
require "bundler/inline"

gemfile do
  source "https://rubygems.org"
  gem "excon"
  gem "json"
end

find, replace = *ARGV

if find.nil? || replace.nil?
  $stderr.puts "You must supply the string to find and replace as arguments. ruby replace.rb <find> <replace>"
  exit(1)
end

endpoint = ENV.fetch("DD_URL", "https://api.datadoghq.com")
headers = {
  "DD-API-KEY" => ENV.fetch("DD_API_KEY"),
  "DD-APPLICATION-KEY" => ENV.fetch("DD_APP_KEY"),
  "Accept" => "application/json",
  "Content-Type" => "application/json",
}

resp = Excon.get(URI.join(endpoint, "/api/v1/monitor").to_s, headers: headers)

monitors = JSON.parse(resp.body)
puts "Found #{monitors.count} monitors"
monitors.reject { |m| m.fetch("type") == "synthetics alert" }.each do |monitor|
  if (msg = monitor.fetch("message")).include?(find)
    puts "Monitor #{monitor.fetch("name").inspect} matched." 
    puts
    puts "Current message:"
    puts "---"
    puts msg
    replaced = msg.gsub(find, replace)
    puts "---"
    puts
    puts "New message:"
    puts "---"
    puts replaced
    puts "---"
    puts "Update? Type 'y' and press enter." unless ENV["UPDATE_ALL"]
    if ENV["UPDATE_ALL"] || $stdin.gets.chomp == 'y'
      resp = Excon.put(URI.join(endpoint, "/api/v1/monitor/#{monitor.fetch("id")}").to_s, headers: headers, body: JSON.dump({
        message: replaced
      }), expects: [200])
      puts resp.body
    else
      puts "Skipping."
      puts "-----"
    end
  end
end

resp = Excon.get(URI.join(endpoint, "/api/v1/synthetics/tests").to_s, headers: headers)

synthetics = JSON.parse(resp.body).fetch("tests")
puts "Found #{synthetics.count} synthetics tests"
synthetics.each do |syn|
  if (msg = syn.fetch("message")).include?(find)
    pp syn
    puts "Synthetics Test #{syn.fetch("name").inspect} matched." 
    puts
    puts "Current message:"
    puts "---"
    puts msg
    replaced = msg.gsub(find, replace)
    puts "---"
    puts
    puts "New message:"
    puts "---"
    puts replaced
    puts "---"
    
    puts "Update? Type 'y' and press enter." unless ENV["UPDATE_ALL"]
    if ENV["UPDATE_ALL"] || $stdin.gets.chomp == 'y'
      resp = Excon.put(URI.join(endpoint, "/api/v1/synthetics/tests/#{syn.fetch("public_id")}").to_s, headers: headers, body: JSON.dump({
        message: replaced,
      }.merge(syn.slice("type", "subtype", "status", "config", "locations", "name", "options", "method", "tags"))))
      if resp.status != 200
        $stderr.puts "ERROR:"
        $stderr.puts resp.body
        exit(1)
      end
    else
      puts "Skipping."
      puts "-----"
    end
  end
end