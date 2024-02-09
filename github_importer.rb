class GithubImporter

    def initialize
        @client = Octokit::Client.new(:access_token => Settings.github.token)
        @client.auto_paginate = true
    end

    def stats
        puts "Logged into Github as #{@client.user.login} (#{@client.user.name})"
        puts "Number of accessible repos: #{@client.repos.size}"
        @client.repos.each { |r| puts " ##{r.id} - #{r.full_name}" }
        puts "Selected repo: #{Settings.github.repo}"
        puts "Labels"
        @client.labels(Settings.github.repo).each { |l| puts " #{l.name} - #{l.color}"}
        puts "Milestones"
        @client.list_milestones(Settings.github.repo).each { |m| puts " #{m.title}"}
        puts "Collaborators"
        @client.collaborators(Settings.github.repo).each { |c| puts " ##{c.id} - #{c.login}"}
        puts "Assignees"
        @client.repository_assignees(Settings.github.repo).each { |a| puts " ##{a.id} - #{a.login}"}
    end

    def label?(label)
        begin
            @client.label(Settings.github.repo, label).name == label
        rescue Octokit::NotFound
            false
        end
    end

    def meta(issue)
        "##{issue.id}: #{issue.subject} - #{issue.status&.name}, #{issue.tracker&.name}, #{issue.category&.name}, #{issue.priority&.name}" 
    end

    def description(issue)
        desc = "```#{Settings.github.i18n.author} #{issue.author&.name} #{issue.created_on} #{Settings.github.i18n.changed} #{issue.updated_on}```"
        desc += "\n\n## #{Settings.github.i18n.description}\n" + "#{issue.description}"
        desc += "\n\n## #{Settings.github.i18n.comments}\n" + notes(issue).join("\n\n") if notes(issue).size > 0
        issue_hash = deep_convert(issue)
        pretty_issue_json = JSON.pretty_generate(issue_hash)
        desc += "\n\n## #{Settings.github.i18n.json}\n" + "```\n" + pretty_issue_json + "\n```"
        desc
    end

    def deep_convert(obj)
        if obj.is_a?(OpenStruct)
            obj.to_h.transform_values { |v| deep_convert(v) }
        elsif obj.is_a?(Array)
            obj.map { |v| deep_convert(v) }
        else
            obj
        end
    end

    def notes(issue)
        notes = []
        issue.journals.each do |j|
            if j.notes && !j.notes.strip.empty?
                quoted_notes = "> " + j.notes.gsub("\n", "\n> ")
                notes << "#{quoted_notes} ```#{j.user.name} #{j.created_on}```"
            end
        end
        notes
    end

    def labels(issue)
        labels = []
        labels << Settings.mappings.tracker[issue.tracker.name.downcase.to_sym] if issue.tracker
        labels << Settings.mappings.category[issue.category.name.downcase.to_sym] if issue.category
        labels << Settings.mappings.priority[issue.priority.name.downcase.to_sym] if issue.priority
        labels.compact!
        labels.each do |l|
            if !label?(l) 
                puts "Creating label #{l}"
                @client.add_label(Settings.github.repo, l, Settings.github.label_defaultcolor) unless Settings.dryrun
            end
        end
        labels
    end
    
    def status(issue)
        Settings.mappings.status[issue.status.name.downcase.to_sym] if issue.status
    end

    def subject(issue)
        issue.subject
    end

    def check_ratelimit
         # Check rate limit
        headers = @client.last_response.headers
        ratelimit_remaining = headers[:x_ratelimit_remaining].to_i
        ratelimit_limit = headers[:x_ratelimit_limit].to_i
        puts "#{ratelimit_remaining} requests remaining of #{ratelimit_limit} requests"
        if ratelimit_remaining < 10
            puts "Approaching rate limit, sleeping for a while..."
            sleep(60)
        end
    end

    def create_issue(issue)
        response = @client.create_issue(
                    Settings.github.repo, 
                    subject(issue), 
                    description(issue),
                    labels: labels(issue)) unless Settings.dryrun
        if response
            puts "Created issue ##{response.number}"
            # Close issue if it's closed in Redmine
            if status(issue) == :close
                puts "Closing issue ##{response.number}"
                @client.update_issue(Settings.github.repo, response.number, state: 'closed') unless Settings.dryrun
            end
        end
    end

    def import
        Dir.entries(Settings.redmine.json_dir).reject {|f| File.directory? f}.shuffle.each do |f| 
            issue = JSON.parse(File.read("#{Settings.redmine.json_dir}/#{f}"), object_class: OpenStruct).issue
            check_ratelimit
            puts "Loaded #{meta(issue)}"
            puts "Creating issue ##{issue.id} with labels #{labels(issue)} and status #{status(issue)}"
            # Search for existing issues with the same title
            existing_issues = @client.search_issues("\"#{subject(issue)}\" in:title repo:#{Settings.github.repo}")
            if existing_issues.total_count > 0
                puts "Issue ##{issue.id} already exists, skipping"
                next
            end
            # puts description(issue)
            success = false
            retry_after = 60
            until success
                begin
                    create_issue(issue)
                    success = true
                rescue Octokit::TooManyRequests => e
                    puts "Received a 403 error: #{e.message}, sleeping for a while..."
                    headers = e.response_headers
                    # ap headers
                    sleep(retry_after)
                    retry_after += 60
                end
            end
        end
    end

end