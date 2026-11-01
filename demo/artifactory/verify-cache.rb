#!/usr/bin/env ruby
require 'digest'
require 'net/http'
require 'uri'

here = File.expand_path(__dir__)
# ARTIFACTORY_URL selects the instance (default http://localhost:8082).
BASE_URL = URI(ENV.fetch('ARTIFACTORY_URL', 'http://localhost:8082').chomp('/'))
env = File.readlines(File.join(here, '.env')).each_with_object({}) do |line, values|
  key, value = line.strip.split('=', 2)
  values[key] = value if key && value
end
password = env.fetch('ARTIFACTORY_ADMIN_PASSWORD')
artifact = '/org/springframework/boot/spring-boot-starter-parent/3.4.17.1/' \
           'spring-boot-starter-parent-3.4.17.1.pom'

def fetch(repository, artifact, password)
  request = Net::HTTP::Get.new("/artifactory/#{repository}#{artifact}")
  request.basic_auth('admin', password)
  Net::HTTP.start(BASE_URL.host, BASE_URL.port, read_timeout: 60) { |http| http.request(request) }
end

remote = fetch('spring-enterprise-remote', artifact, password)
cache = fetch('spring-enterprise-remote-cache', artifact, password)
unless remote.code == '200' && cache.code == '200' && remote.body == cache.body
  raise "Mirror check failed: remote=#{remote.code}, cache=#{cache.code}"
end
puts "Cached Spring Boot 3.4.17.1 POM (#{remote.body.bytesize} bytes)."
puts "Remote/cache SHA-256: #{Digest::SHA256.hexdigest(remote.body)[0, 16]}"
