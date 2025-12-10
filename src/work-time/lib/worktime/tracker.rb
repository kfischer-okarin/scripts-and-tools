# frozen_string_literal: true

require "csv"
require "fileutils"
require "time"

module Worktime
  class AlreadyWorkingError < StandardError; end
  class LunchAlreadyTakenError < StandardError; end
  class NotWorkingError < StandardError; end

  class Tracker
    Status = Data.define(:state, :work_minutes, :todays_surplus_minutes, :month_surplus_minutes, :projected_end_time, :projected_end_time_for_zero_surplus)
    DayStats = Data.define(:date, :work_minutes, :surplus_minutes)
    MonthStats = Data.define(:days, :total_surplus_minutes)

    def initialize(data_dir:, now: Time.now)
      @data_dir = data_dir
      @now = now
      load_events
      load_overrides
    end

    def start
      raise AlreadyWorkingError if state == :working

      record_event(:start)
    end

    def stop
      raise NotWorkingError if state == :stopped

      record_event(:stop)
    end

    def toggle_break
      raise NotWorkingError if state == :stopped

      record_event(state == :on_break ? :break_end : :break_start)
    end

    def toggle_lunch
      raise NotWorkingError if state == :stopped
      raise LunchAlreadyTakenError if lunch_taken? && state != :on_lunch

      record_event(state == :on_lunch ? :lunch_end : :lunch_start)
    end

    def status
      Status.new(
        state: state,
        work_minutes: work_minutes,
        todays_surplus_minutes: todays_surplus_minutes,
        month_surplus_minutes: month_surplus_minutes,
        projected_end_time: projected_end_time,
        projected_end_time_for_zero_surplus: projected_end_time_for_zero_surplus
      )
    end

    def set_hours(hours, date: @now.to_date)
      @overrides[date] = hours
      save_overrides
    end

    def month_statistics
      dates = @events.map { |e| e[:date] }.uniq.sort
      days = dates.map do |date|
        work_mins = work_minutes_for_date(date)
        expected_mins = expected_minutes_for_date(date)
        DayStats.new(date: date, work_minutes: work_mins, surplus_minutes: work_mins - expected_mins)
      end
      MonthStats.new(days: days, total_surplus_minutes: days.sum(&:surplus_minutes))
    end

    private

    def projected_end_time
      events = events_for_date(@now.to_date)
      start_event = events.find { |e| e[:event] == :start }
      return nil unless start_event

      remaining_work = expected_minutes - worked_minutes_so_far
      end_time = @now + (remaining_work * 60)
      end_time += (60 * 60) unless lunch_taken?
      end_time
    end

    def projected_end_time_for_zero_surplus
      events = events_for_date(@now.to_date)
      start_event = events.find { |e| e[:event] == :start }
      return nil unless start_event

      previous_days_surplus = month_statistics.days
        .reject { |d| d.date == @now.to_date }
        .sum(&:surplus_minutes)
      remaining_for_today = expected_minutes - worked_minutes_so_far
      remaining_work = remaining_for_today - previous_days_surplus

      end_time = @now + (remaining_work * 60)
      end_time += (60 * 60) unless lunch_taken?
      end_time
    end

    def worked_minutes_so_far
      events = events_for_date(@now.to_date)
      start_event = events.find { |e| e[:event] == :start }
      return 0 unless start_event

      start_time = parse_time_for_date(start_event[:time], @now.to_date)
      total = ((@now - start_time) / 60).to_i
      total - break_minutes_for_date(events, @now.to_date)
    end

    def todays_surplus_minutes
      work_minutes - expected_minutes
    end

    def month_surplus_minutes
      month_statistics.total_surplus_minutes
    end

    def expected_minutes
      expected_minutes_for_date(@now.to_date)
    end

    def expected_minutes_for_date(date)
      hours = @overrides.fetch(date, 8)
      hours * 60
    end

    def work_minutes
      work_minutes_for_date(@now.to_date)
    end

    def work_minutes_for_date(date)
      events = events_for_date(date)
      return 0 if events.empty?

      start_event = events.find { |e| e[:event] == :start }
      stop_event = events.find { |e| e[:event] == :stop }
      return 0 unless start_event && stop_event

      start_time = parse_time_for_date(start_event[:time], date)
      stop_time = parse_time_for_date(stop_event[:time], date)
      total = ((stop_time - start_time) / 60).to_i

      total - break_minutes_for_date(events, date)
    end

    def break_minutes_for_date(events, date)
      total = 0
      break_start = nil

      events.each do |event|
        case event[:event]
        when :break_start, :lunch_start
          break_start = parse_time_for_date(event[:time], date)
        when :break_end, :lunch_end
          total += ((parse_time_for_date(event[:time], date) - break_start) / 60).to_i if break_start
          break_start = nil
        end
      end

      total
    end

    def parse_time_for_date(time_str, date)
      hour, min = time_str.split(":").map(&:to_i)
      Time.new(date.year, date.month, date.day, hour, min, 0)
    end

    def state
      today_events = events_for_date(@now.to_date)
      return :stopped if today_events.empty?

      last_event = today_events.last[:event]
      case last_event
      when :start, :break_end, :lunch_end then :working
      when :stop then :stopped
      when :break_start then :on_break
      when :lunch_start then :on_lunch
      else :stopped
      end
    end

    def lunch_taken?
      events_for_date(@now.to_date).any? { |e| e[:event] == :lunch_end }
    end

    def events_for_date(date)
      @events.select { |e| e[:date] == date }
    end

    def record_event(event_type)
      @events << { date: @now.to_date, event: event_type, time: @now.strftime("%H:%M") }
      save_events
    end

    def csv_path
      File.join(@data_dir, "#{@now.strftime('%Y-%m')}.csv")
    end

    def load_events
      @events = []
      return unless File.exist?(csv_path)

      CSV.foreach(csv_path, headers: true, header_converters: :symbol) do |row|
        @events << {
          date: Date.parse(row[:date]),
          event: row[:event].to_sym,
          time: row[:time]
        }
      end
    end

    def save_events
      FileUtils.mkdir_p(@data_dir)
      CSV.open(csv_path, "w") do |csv|
        csv << %w[date event time]
        @events.each do |e|
          csv << [e[:date], e[:event], e[:time]]
        end
      end
    end

    def overrides_path
      File.join(@data_dir, "#{@now.strftime('%Y-%m')}-worktime-overrides.csv")
    end

    def load_overrides
      @overrides = {}
      return unless File.exist?(overrides_path)

      CSV.foreach(overrides_path, headers: true, header_converters: :symbol) do |row|
        @overrides[Date.parse(row[:date])] = row[:expected_hours].to_i
      end
    end

    def save_overrides
      FileUtils.mkdir_p(@data_dir)
      CSV.open(overrides_path, "w") do |csv|
        csv << %w[date expected_hours]
        @overrides.each do |date, hours|
          csv << [date, hours]
        end
      end
    end
  end
end
