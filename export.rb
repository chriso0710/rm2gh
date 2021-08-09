require 'dotenv'
require 'excon'
require 'json'
require 'awesome_print'
require 'ostruct'
require 'octokit'

class RedmineExporter
    ISSUES_PATH = "/issues.json"
    ISSUE_PATH = "/issues/%s.json"
    PROJECTS_PATH = "/projects.json"

    def initialize
        @connection = Excon.new(ENV['REDMINE_URL'], :headers => {'X-Redmine-API-Key' => ENV['REDMINE_API_KEY']}, 
                                :debug_request => true, :debug_response => true)
        Dir.mkdir(ENV['JSON_DIR']) unless Dir.exist?(ENV['JSON_DIR'])
    end

    def pages(path, options = {})
        query = {:limit => 1}
        query.merge!(options)
        response = @connection.get(:path => path, :query => query, :expects => [200, 201])
        j = JSON.parse response.body
        total = j["total_count"]
        pages = (total/100.0).ceil
        OpenStruct.new(:path => path, :total => total, :pages => pages)
    end

    def load_projects
        projects = []
        pages(PROJECTS_PATH).pages.times do |p|
            query = {:limit => 100, :offset => p*100}
            response = @connection.get(:path => PROJECTS_PATH, :query => query, :expects => [200, 201])
            j = JSON.parse(response.body)
            projects.push(*j["projects"])
        end
        projects
    end

    def projects
        @projects ||= load_projects
    end

    def load_issues
        issues = []
        query = {}
        query.merge!({:project_id => ENV['REDMINE_PROJECT_ID'].to_i}) if ENV['REDMINE_PROJECT_ID']
        query.merge!({:status_id => "*"})
        pages(ISSUES_PATH, query).pages.times do |p|
            query.merge!({:limit => 100, :offset => p*100})
            response = @connection.get(:path => ISSUES_PATH, :query => query, :expects => [200, 201])
            j = JSON.parse(response.body)
            issues.push(*j["issues"])
        end
        issues
    end

    def issues
        @issues ||= load_issues
    end

    def issue(id)
        query = {:include => "journals"}
        response = @connection.get(:path => ISSUE_PATH % id, :query => query, :expects => [200, 201])
        JSON.parse(response.body)
    end

    def filename(id)
        "#{ENV['JSON_DIR']}/#{id}.json"
    end

    def export
        issues.each do |i|
            id = i["id"]
            File.write(filename(id), JSON.pretty_generate(issue(id))) unless File.exist?(filename(id))
        end
    end

    def priority_labels
        issues.map{ |i| i["priority"]["name"] if i["priority"] }.uniq.compact
    end

    def tracker_labels
        issues.map{ |i| i["tracker"]["name"] if i["tracker"] }.uniq.compact
    end

    def status_labels
        issues.map{ |i| i["status"]["name"] if i["status"] }.uniq.compact
    end

    def assigned_to
        issues.map{ |i| i["assigned_to"]["name"] if i["assigned_to"] }.uniq.compact
    end

    def category_labels
        issues.map{ |i| i["category"]["name"] if i["category"] }.uniq.compact
    end

end

class GithubImporter

    def initialize
        @client = Octokit::Client.new(:access_token => ENV['GITHUB_TOKEN'])
        @client.auto_paginate = true
    end

    def stats
        puts "Logged into Github as #{@client.user.login}, #{@client.user.name}"
        puts "Number of repos: #{@client.repos.size}"
        @client.repos.each { |r| puts " ##{r.id} - #{r.full_name}" }
        ap @client.labels(ENV['GITHUB_REPO'])
        ap @client.list_milestones(ENV['GITHUB_REPO'])
        ap @client.repository_assignees(ENV['GITHUB_REPO'])
        # response = @client.create_issue(ENV['GITHUB_REPO'], 'Updated Docs', 'Added some extra links')
        # ap response
    end

    def meta(issue)
        i = issue.issue
        puts "#{i.id} - #{i.tracker.name}"
    end

    def import
        Dir.entries(ENV['JSON_DIR']).reject {|f| File.directory? f}.each do |f| 
            issue = File.read("#{ENV['JSON_DIR']}/#{f}")
            meta JSON.parse(issue, object_class: OpenStruct)
        end
    end

end

Dotenv.load

redmine = RedmineExporter.new
puts "Connecting to #{ENV['REDMINE_URL']}"
puts "Number of projects: #{redmine.projects.size}"
redmine.projects.each { |p| puts " ##{p["id"]} - #{p["name"]}" }
puts "Number of issues to export: #{redmine.issues.size}"
puts "Unique Priorities: #{redmine.priority_labels.join(",")}"
puts "Unique Categories: #{redmine.category_labels.join(",")}"
puts "Unique Trackers: #{redmine.tracker_labels.join(",")}"
puts "Unique Statuses: #{redmine.status_labels.join(",")}"
puts "Unique Assignees: #{redmine.assigned_to.join(",")}"

redmine.issues.each do |i|
   id = i["id"]
   # puts "id: #{id} - #{i["project"]["name"]} - #{i["subject"]} - #{i["status"]["name"]}"
end
# redmine.export
ap eval ENV['TRACKER_MAP']
ap eval ENV['CATEGORY_MAP']
ap eval ENV['STATUS_OPENCLOSE_MAP']

github = GithubImporter.new
github.import
# github.stats