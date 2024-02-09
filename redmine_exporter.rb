class RedmineExporter
    ISSUES_PATH = "/issues.json"
    ISSUE_PATH = "/issues/%s.json"
    PROJECTS_PATH = "/projects.json"

    def initialize
        @connection = Excon.new(Settings.redmine.url, 
                                :headers => {'X-Redmine-API-Key' => Settings.redmine.api_key}, 
                                :debug_request => true, :debug_response => true)
        Dir.mkdir(Settings.redmine.json_dir) unless Dir.exist?(Settings.redmine.json_dir)
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
        query.merge!({:project_id => Settings.redmine.project_id.to_i}) if Settings.redmine.project_id
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
        "#{Settings.redmine.json_dir}/#{id}.json"
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

    def fixed_version
        issues.map{ |i| i["fixed_version"]["name"] if i["fixed_version"] }.uniq.compact
    end

    def stats
        puts "Number of accessible projects: #{projects.size}"
        projects.each { |p| puts " ##{p["id"]} - #{p["name"]}" }
        puts "Selected project: ##{Settings.redmine.project_id}"
        puts "Number of issues to export: #{issues.size}"
        puts "Priorities: #{priority_labels.join(",")}"
        puts "Categories: #{category_labels.join(",")}"
        puts "Trackers: #{tracker_labels.join(",")}"
        puts "Statuses: #{status_labels.join(",")}"
        puts "Assignees: #{assigned_to.join(",")}"
        puts "Fixed Versions: #{fixed_version.join(",")}"
    end

end