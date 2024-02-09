VERSION = "0.1.0"
require 'excon'
require 'json'
require 'awesome_print'
require 'ostruct'
require 'octokit'
require 'config'
require_relative 'github_importer'
require_relative 'redmine_exporter'

Config.load_and_set_settings("./settings.yml")
puts "Version #{VERSION}"
puts "Dryrun" if Settings.dryrun
# ap Settings.mappings.status
# ap Settings.mappings.tracker["Support".to_sym]

unless Settings.redmine.skip
   puts "--- Redmine"
   redmine = RedmineExporter.new
   puts "Connecting to #{Settings.redmine.url}"
   redmine.stats

   redmine.issues.each do |i|
      puts "id: #{i["id"]} - #{i["project"]["name"]} - #{i["subject"]} - #{i["status"]["name"]}"
   end
   redmine.export unless Settings.dryrun
end

unless Settings.github.skip
   puts "--- Github"
   github = GithubImporter.new
   puts "Connecting to Github"
   github.stats
   github.import unless Settings.dryrun
end