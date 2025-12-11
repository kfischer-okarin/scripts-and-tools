# frozen_string_literal: true

require "json"

require "thor"

require_relative "tracker"

module Worktime
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "start", "Start working"
    def start
      t = tracker
      was_stopped = t.status.state == :stopped
      t.start
      if was_stopped
        puts "Resumed working at #{Time.now.strftime('%H:%M')}"
      else
        puts "Started working at #{Time.now.strftime('%H:%M')}"
      end
    rescue AlreadyWorkingError
      warn "Already working"
    end

    desc "stop", "Stop working"
    def stop
      tracker.stop
      puts "Stopped working at #{Time.now.strftime('%H:%M')}"
    rescue OutsideWorkingHoursError
      warn "Not currently working"
    end

    desc "lunch", "Toggle lunch break"
    def lunch
      tracker.toggle_lunch
      status = tracker.status
      if status.state == :on_lunch
        puts "Started lunch at #{Time.now.strftime('%H:%M')}"
      else
        puts "Ended lunch at #{Time.now.strftime('%H:%M')}"
      end
    rescue OutsideWorkingHoursError
      warn "Not currently working"
    rescue LunchAlreadyTakenError
      warn "Lunch already taken today"
    end

    desc "break", "Toggle break"
    method_option :break
    def break
      tracker.toggle_break
      status = tracker.status
      if status.state == :on_break
        puts "Started break at #{Time.now.strftime('%H:%M')}"
      else
        puts "Ended break at #{Time.now.strftime('%H:%M')}"
      end
    rescue OutsideWorkingHoursError
      warn "Not currently working"
    end

    desc "status [DATE]", "Show current status (optionally for a specific date YYYY-MM-DD)"
    method_option :json, type: :boolean, desc: "Output as JSON"
    def status(date = nil)
      t = tracker(date ? parse_date(date) : Time.now)
      s = t.status

      if options[:json]
        puts JSON.pretty_generate(s.to_json_hash)
      else
        puts s.to_cli_output
      end
    end

    desc "month [MONTH]", "Show month statistics (optionally for a specific month YYYY-MM)"
    def month(month = nil)
      now = month ? parse_month(month) : Time.now
      t = tracker(now)
      stats = t.month_statistics

      puts "Month: #{now.strftime('%Y-%m')}"
      puts "Date             | Work     | Overtime"
      puts "-" * 41
      stats.days.each do |day|
        row = "#{day.date} (#{day.date.strftime('%a')}) | #{format_duration(day.work_minutes).rjust(8)} | #{format_overtime(day.overtime_minutes).rjust(7)}"
        row += "  [#{day.expected_minutes / 60}h expected]" if day.expected_minutes != 480
        puts row
      end
      puts "-" * 41
      puts "Total overtime: #{format_overtime(stats.total_overtime_minutes)}"
    end

    desc "set_hours HOURS", "Set expected hours for a day (default: today)"
    method_option :date, type: :string, desc: "Date to set hours for (YYYY-MM-DD)"
    def set_hours(hours)
      date = options[:date] ? Date.parse(options[:date]) : Date.today
      tracker.set_hours(hours.to_i, date: date)
      puts "Set expected hours for #{date} to #{hours}"
    end

    private

    def tracker(now = Time.now)
      Tracker.new(data_dir: data_dir, now: now)
    end

    def data_dir
      ENV.fetch("WORKTIME_DATA_DIR") { File.join(xdg_data_home, "worktime") }
    end

    def xdg_data_home
      ENV.fetch("XDG_DATA_HOME") { File.expand_path("~/.local/share") }
    end

    def parse_date(date_str)
      date = Date.parse(date_str)
      Time.new(date.year, date.month, date.day, 12, 0, 0)
    end

    def parse_month(month_str)
      year, month = month_str.split("-").map(&:to_i)
      Time.new(year, month, 15, 12, 0, 0)
    end

    def format_duration(minutes)
      hours = minutes / 60
      mins = minutes % 60
      "#{hours}:#{mins.to_s.rjust(2, '0')}"
    end

    def format_overtime(minutes)
      sign = minutes >= 0 ? "+" : "-"
      "#{sign}#{format_duration(minutes.abs)}"
    end
  end
end
