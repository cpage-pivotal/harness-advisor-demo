#!/usr/bin/env ruby
# Configure the Artifactory Maven remote without putting credentials in Git.
# ARTIFACTORY_URL selects the instance (default http://localhost:8082), for example
# ARTIFACTORY_URL=http://192.168.5.40:8082 when Artifactory runs on another host.
require 'json'
require 'net/http'
require 'rexml/document'
require 'rexml/xpath'
require 'uri'
require 'yaml'

here = File.expand_path(__dir__)
BASE_URL = URI(ENV.fetch('ARTIFACTORY_URL', 'http://localhost:8082').chomp('/'))
repo = File.expand_path('../..', here)
vars = YAML.safe_load(File.read(File.join(repo, 'vars.yaml')))
token = vars.fetch('BROADCOM_REGISTRY_TOKEN')
raise 'BROADCOM_REGISTRY_TOKEN is empty' if token.to_s.empty?

env = File.readlines(File.join(here, '.env')).each_with_object({}) do |line, values|
  key, value = line.strip.split('=', 2)
  values[key] = value if key && value
end
admin_password = env.fetch('ARTIFACTORY_ADMIN_PASSWORD')

settings_path = File.join(Dir.home, '.m2', 'settings.xml')
settings = REXML::Document.new(File.read(settings_path))
server = REXML::XPath.match(settings, '//server').find do |item|
  item.elements['id']&.text == 'spring-enterprise-subscription'
end
username = ENV['BROADCOM_EMAIL'] || server&.elements&.[]('username')&.text
raise 'Broadcom email is missing from Maven settings and BROADCOM_EMAIL' if username.to_s.empty?

def call_api(method, path, password, data = nil, content_type = 'application/json')
  request_class = { get: Net::HTTP::Get, post: Net::HTTP::Post, patch: Net::HTTP::Patch }.fetch(method)
  request = request_class.new(path)
  request.basic_auth('admin', password)
  if data
    request['Content-Type'] = content_type
    request.body = content_type == 'application/yaml' ? YAML.dump(data) : JSON.generate(data)
  end
  Net::HTTP.start(BASE_URL.host, BASE_URL.port, open_timeout: 10, read_timeout: 45) do |http|
    http.request(request)
  end
end

auth_check = call_api(:get, '/artifactory/api/repositories', admin_password)
unless auth_check.code == '200'
  changed = call_api(:post, '/artifactory/api/security/users/authorization/changePassword', 'password', {
    userName: 'admin', oldPassword: 'password', newPassword1: admin_password,
    newPassword2: admin_password
  })
  raise "Could not set the local admin password (HTTP #{changed.code})" unless changed.code.start_with?('2')
  auth_check = call_api(:get, '/artifactory/api/repositories', admin_password)
  raise "Local admin authentication failed (HTTP #{auth_check.code})" unless auth_check.code == '200'
end

key = 'spring-enterprise-remote'
upstream = 'https://packages.broadcom.com/artifactory/spring-enterprise'
config = {
  'remoteRepositories' => {
    key => {
      'type' => 'maven',
      'url' => upstream,
      'username' => username,
      'password' => token,
      'enableTokenAuthentication' => true,
      'storeArtifactsLocally' => true
    }
  }
}
backup = call_api(:get, '/artifactory/api/system/configuration', admin_password)
raise "Could not back up Artifactory configuration (HTTP #{backup.code})" unless backup.code == '200'
backup_dir = File.join(here, 'downloads')
Dir.mkdir(backup_dir) unless Dir.exist?(backup_dir)
backup_file = File.join(backup_dir, "config-before-#{Time.now.utc.strftime('%Y%m%d-%H%M%S')}.yaml")
File.open(backup_file, File::WRONLY | File::CREAT | File::EXCL, 0o600) { |file| file.write(backup.body) }

result = call_api(:patch, '/artifactory/api/system/configuration', admin_password,
                  config, 'application/yaml')
unless result.code.start_with?('2')
  message = result.body.to_s.gsub(token, '[redacted]').gsub(admin_password, '[redacted]')
  raise "Could not configure remote (HTTP #{result.code}): #{message[0, 300]}"
end

verified = call_api(:get, '/artifactory/api/repositories', admin_password)
raise "Remote verification failed (HTTP #{verified.code})" unless verified.code == '200'
repositories = JSON.parse(verified.body)
raise 'Remote repository was not listed' unless repositories.any? { |item| item['key'] == key }
puts "Configured #{key} as a Maven remote with Broadcom Bearer authentication."
puts "URL: #{BASE_URL}/artifactory/spring-enterprise-remote"
puts "Configuration backup: #{backup_file}"
