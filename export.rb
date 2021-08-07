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

    def stats
        puts "Number of projects: #{pages(PROJECTS_PATH).total}"
        projects.each do |p|
            puts " ##{p.id} - #{p.name}"
        end
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

    def projects
        projects = []
        pages(PROJECTS_PATH).pages.times do |p|
            query = {:limit => 100, :offset => p*100}
            response = @connection.get(:path => PROJECTS_PATH, :query => query, :expects => [200, 201])
            j = JSON.parse(response.body, object_class: OpenStruct)
            projects.push(*j["projects"])
        end
        projects
    end

    def issues
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

    def issue(id)
        query = {:include => "journals"}
        response = @connection.get(:path => ISSUE_PATH % id, :query => query, :expects => [200, 201])
        JSON.parse(response.body)
    end

    def filename(id)
        "#{ENV['JSON_DIR']}/#{id}.json"
    end

    def create_files
        issues.each do |i|
            id = i["id"]
            puts "id: #{id} - #{i["project"]["name"]} - #{i["subject"]} - #{i["status"]["name"]}"
            File.write(filename(id), JSON.pretty_generate(issue(id))) unless File.exist?(filename(id))
        end    
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
        @client.repos.each do |r|
            puts " ##{r.id} - #{r.full_name}"
        end
    end

end

Dotenv.load

redmine = RedmineExporter.new
# puts "Connecting to #{ENV['REDMINE_URL']}"
# redmine.stats
# issues = redmine.issues
# puts "Number of issues: #{issues.size}"
# redmine.create_files

github = GithubImporter.new
github.stats