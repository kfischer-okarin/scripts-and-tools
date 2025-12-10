# frozen_string_literal: true

require "thor"
require_relative "tracker"

module Worktime
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "start", "Start working"
    def start
      tracker.start
      puts "Started working at #{Time.now.strftime('%H:%M')}"
    rescue AlreadyWorkingError
      warn "Already working"
    end

    desc "stop", "Stop working"
    def stop
      tracker.stop
      puts "Stopped working at #{Time.now.strftime('%H:%M')}"
    rescue NotWorkingError
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
    rescue NotWorkingError
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
    rescue NotWorkingError
      warn "Not currently working"
    end

    desc "status [DATE]", "Show current status (optionally for a specific date YYYY-MM-DD)"
    method_option :json, type: :boolean, desc: "Output as JSON"
    def status(date = nil)
      t = tracker(date ? parse_date(date) : Time.now)
      s = t.status

      if options[:json]
        require "json"
        puts JSON.pretty_generate(
          state: s.state,
          work_minutes: s.work_minutes,
          todays_surplus_minutes: s.todays_surplus_minutes,
          month_surplus_minutes: s.month_surplus_minutes,
          remaining_lunch_break_minutes: s.remaining_lunch_break_minutes,
          projected_end_time: s.projected_end_time&.iso8601,
          projected_end_time_for_zero_surplus: s.projected_end_time_for_zero_surplus&.iso8601
        )
      else
        puts "State: #{s.state}"
        puts "Work today: #{format_duration(s.work_minutes)}"
        puts "Today's surplus: #{format_surplus(s.todays_surplus_minutes)}"
        puts "Month surplus: #{format_surplus(s.month_surplus_minutes)}"
        puts "Remaining lunch: #{s.remaining_lunch_break_minutes}m"
        if s.state != :stopped
          puts "Projected end: #{s.projected_end_time&.strftime('%H:%M') || 'N/A'}"
          puts "End for zero surplus: #{s.projected_end_time_for_zero_surplus&.strftime('%H:%M') || 'N/A'}"
        end
      end
    end

    desc "month [MONTH]", "Show month statistics (optionally for a specific month YYYY-MM)"
    def month(month = nil)
      now = month ? parse_month(month) : Time.now
      t = tracker(now)
      stats = t.month_statistics

      puts "Month: #{now.strftime('%Y-%m')}"
      puts "Date       | Work     | Surplus"
      puts "-" * 35
      stats.days.each do |day|
        puts "#{day.date} | #{format_duration(day.work_minutes).rjust(8)} | #{format_surplus(day.surplus_minutes).rjust(7)}"
      end
      puts "-" * 35
      puts "Total surplus: #{format_surplus(stats.total_surplus_minutes)}"
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
      "#{hours}h #{mins.to_s.rjust(2, '0')}m"
    end

    def format_surplus(minutes)
      sign = minutes >= 0 ? "+" : "-"
      "#{sign}#{format_duration(minutes.abs)}"
    end
  end
end
