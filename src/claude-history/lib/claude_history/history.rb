# frozen_string_literal: true

require "date"

module ClaudeHistory
  # The whole ~/.claude/projects tree: finds projects, and resolves the file a
  # session id refers to.
  class History
    def initialize(projects_path)
      @projects_path = projects_path
    end

    def projects
      Dir.glob(File.join(@projects_path, "*"))
         .select { |path| File.directory?(path) }
         .map { |path| Project.new(path) }
    end

    def project(project_id)
      Project.new(File.join(@projects_path, project_id))
    end

    def sessions(project_id:, agents: false)
      project(project_id).sessions(agents: agents)
    end

    def all_sessions(agents: false)
      projects.flat_map { |project| project.sessions(agents: agents) }
    end

    def resolve_project_id(query)
      all_ids = projects.map(&:id)
      return query if all_ids.include?(query)

      unique_match!(all_ids.select { |id| id.include?(query) }, query, "project") { |id| id }
    end

    # A session id names a file, so resolving one is a file lookup: an exact hit
    # first, then a prefix search. Without a project the search covers them all,
    # which is still only file names.
    def resolve_session(query, project_id: nil)
      searched = project_id ? [project(project_id)] : projects

      exact = searched.filter_map { |project| project.session(query) }
      return exact.first if exact.any?

      matches = searched.flat_map { |project| project.sessions_matching(query) }
      unique_match!(matches, query, "session", &:id)
    end

    # Sessions whose span of activity covers the date. The file's mtime rules
    # out most sessions without opening them.
    def sessions_updated_on(date, agents: false)
      projects.flat_map { |project|
        project.sessions(agents: agents)
               .select { |session| touched_by?(session, date) && started_by?(session, date) }
               .map { |session| { project: project, session: session } }
      }.sort_by { |result| result[:session].last_updated_at }.reverse
    end

    private

    def touched_by?(session, date)
      session.last_updated_at.getlocal.to_date >= date
    end

    def started_by?(session, date)
      started = session.started_at
      started.nil? || started.getlocal.to_date <= date
    end

    def unique_match!(matches, query, subject)
      raise Error, "No #{subject} found matching '#{query}'" if matches.empty?

      if matches.size > 1
        labels = matches.map { |match| "  - #{yield(match)}" }
        raise Error, "Ambiguous #{subject} '#{query}'. Matches:\n#{labels.join("\n")}"
      end

      matches.first
    end
  end
end
