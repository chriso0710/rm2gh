require 'dotenv'
require 'excon'
require 'json'
require 'awesome_print'
require 'ostruct'

class Redmine

    ISSUES_PATH = "/issues.json"
    ISSUE_PATH = "/issues/%s.json"
    PROJECTS_PATH = "/projects.json"

    def initialize
        @connection = Excon.new(ENV['REDMINE_URL'], :headers => {'X-Redmine-API-Key' => ENV['REDMINE_API_KEY']}, 
                                :debug_request => true, :debug_response => true)
        Dir.mkdir(ENV['JSON_DIR']) unless Dir.exist?(ENV['JSON_DIR'])
    end

    def connection_test
        puts "Connecting to #{ENV['REDMINE_URL']}"
        puts "Number of projects: #{pages(PROJECTS_PATH).total}"
    end

    def pages(path, options = {})
        query = {:limit => 1}
        query.merge!(options)
        response = @connection.get(:path => path, :query => query, :expects => [200, 201])
        j = JSON.parse response.body
        total = j["total_count"]
        pages = (total/100.0).ceil
        OpenStruct.new(:total => total, :pages => pages)
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
        options = {}
        options.merge!({:project_id => ENV['REDMINE_PROJECT_ID'].to_i}) if ENV['REDMINE_PROJECT_ID']
        options.merge!({:status_id => "*"})
        pages(ISSUES_PATH, options).pages.times do |p|
            query = {:limit => 100, :offset => p*100}
            query.merge!(options)
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
            puts "id: #{id} - #{i["project"]["name"]} - #{i["subject"]}"
            File.open(filename(id),"w") do |f|
                f.write(JSON.pretty_generate(issue(id)))
            end
        end    
    end

end

Dotenv.load

redmine = Redmine.new
redmine.connection_test
projects = redmine.projects
projects.each do |p|
    puts "id: #{p.id} - #{p.name}"
end
issues = redmine.issues
puts "Number of issues: #{issues.size}"
ap issues.first.to_json
redmine.create_files