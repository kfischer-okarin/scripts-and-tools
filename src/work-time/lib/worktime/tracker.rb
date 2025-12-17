# frozen_string_literal: true

require "csv"
require "fileutils"
require "time"

require_relative "work_log"

module Worktime
  class AlreadyWorkingError < StandardError; end
  class LunchAlreadyTakenError < StandardError; end
  class OutsideWorkingHoursError < StandardError; end
  class InvalidAdjustmentError < StandardError; end

  module DurationFormatting
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

  class Tracker
    UnstartedStatus = Data.define(:state, :month_overtime_minutes) do
      include DurationFormatting

      def to_json_hash
        { state: state, month_overtime_minutes: month_overtime_minutes }
      end

      def to_cli_output
        <<~OUTPUT.chomp
          State: #{state}
          Month overtime: #{format_overtime(month_overtime_minutes)}
        OUTPUT
      end
    end

    WorkingDayStatus = Data.define(
      :state,
      :start_time,
      :now,
      :break_minutes,
      :expected_minutes,
      :lunch_taken,
      :other_days_overtime_minutes,
      :remaining_lunch_break_minutes,
      :last_event,
      :last_event_time
    ) do
      include DurationFormatting

      def work_minutes
        ((self.now - start_time) / 60).to_i - break_minutes
      end

      def todays_overtime_minutes
        work_minutes - expected_minutes
      end

      def month_overtime_minutes
        other_days_overtime_minutes
      end

      def projected_end_time
        remaining_work = expected_minutes - work_minutes
        end_time = self.now + (remaining_work * 60)
        end_time += (60 * 60) unless lunch_taken
        end_time
      end

      def projected_end_time_for_zero_overtime
        remaining_for_today = expected_minutes - work_minutes
        remaining_work = remaining_for_today - other_days_overtime_minutes
        end_time = self.now + (remaining_work * 60)
        end_time += (60 * 60) unless lunch_taken
        end_time
      end

      def to_json_hash
        {
          state: state,
          start_time: start_time.iso8601,
          lunch_taken: lunch_taken,
          work_minutes: work_minutes,
          todays_overtime_minutes: todays_overtime_minutes,
          month_overtime_minutes: month_overtime_minutes,
          remaining_lunch_break_minutes: remaining_lunch_break_minutes,
          projected_end_time: projected_end_time&.iso8601,
          projected_end_time_for_zero_overtime: projected_end_time_for_zero_overtime&.iso8601,
          last_event: last_event,
          last_event_time: last_event_time
        }
      end

      def to_cli_output
        lines = [
          "State: #{state}",
          "Start time: #{start_time.strftime('%H:%M')}",
          "Lunch taken: #{lunch_taken ? 'Yes' : 'No'}",
          "Work today: #{format_duration(work_minutes)}",
          "Today's overtime: #{format_overtime(todays_overtime_minutes)}",
          "Month overtime: #{format_overtime(month_overtime_minutes)}",
          "Remaining lunch: #{remaining_lunch_break_minutes}m",
          "Projected end: #{projected_end_time&.strftime('%H:%M') || 'N/A'}",
          "End for zero overtime: #{projected_end_time_for_zero_overtime&.strftime('%H:%M') || 'N/A'}"
        ]
        lines << format_last_event if format_last_event
        lines.join("\n")
      end

      def format_last_event
        case last_event
        when :start then nil
        when :break_start then "Break started at #{last_event_time}"
        when :break_end then "Break ended at #{last_event_time}"
        when :lunch_start then "Lunch started at #{last_event_time}"
        when :lunch_end then "Lunch ended at #{last_event_time}"
        end
      end
    end

    FinishedDayStatus = Data.define(
      :state,
      :start_time,
      :stop_time,
      :break_minutes,
      :expected_minutes,
      :other_days_overtime_minutes,
      :last_event,
      :last_event_time
    ) do
      include DurationFormatting

      def work_minutes
        ((stop_time - start_time) / 60).to_i - break_minutes
      end

      def todays_overtime_minutes
        work_minutes - expected_minutes
      end

      def month_overtime_minutes
        other_days_overtime_minutes + todays_overtime_minutes
      end

      def to_json_hash
        {
          state: state,
          work_minutes: work_minutes,
          todays_overtime_minutes: todays_overtime_minutes,
          month_overtime_minutes: month_overtime_minutes,
          last_event: last_event,
          last_event_time: last_event_time
        }
      end

      def to_cli_output
        lines = [
          "State: #{state}",
          "Work today: #{format_duration(work_minutes)}",
          "Today's overtime: #{format_overtime(todays_overtime_minutes)}",
          "Month overtime: #{format_overtime(month_overtime_minutes)}",
          "Finished work at #{last_event_time}"
        ]
        lines.join("\n")
      end
    end
    DayStats = Data.define(:date, :work_minutes, :expected_minutes, :overtime_minutes)
    MonthStats = Data.define(:days, :total_overtime_minutes)

    def initialize(data_dir:, now: Time.now)
      @data_dir = data_dir
      @now = now
      load_events
      load_overrides
    end

    def start
      raise AlreadyWorkingError if state == :working

      if state == :stopped
        resume_after_stop
      else
        record_event(:start)
      end
    end

    def stop
      raise OutsideWorkingHoursError if outside_working_hours?

      record_event(:stop)
    end

    def toggle_break
      raise OutsideWorkingHoursError if outside_working_hours?

      record_event(state == :on_break ? :break_end : :break_start)
    end

    def toggle_lunch
      raise OutsideWorkingHoursError if outside_working_hours?
      raise LunchAlreadyTakenError if lunch_taken? && state != :on_lunch

      record_event(state == :on_lunch ? :lunch_end : :lunch_start)
    end

    def status
      work_log = work_log_for_date(@now.to_date)

      case work_log.state
      when :unstarted
        UnstartedStatus.new(state: :unstarted, month_overtime_minutes: month_overtime_minutes)
      when :stopped
        last = work_log.last_event
        FinishedDayStatus.new(
          state: :stopped,
          start_time: work_log.start_time,
          stop_time: work_log.stop_time,
          break_minutes: break_minutes_for_log(work_log),
          expected_minutes: expected_minutes,
          other_days_overtime_minutes: other_days_overtime_minutes,
          last_event: last&.dig(:event),
          last_event_time: last&.dig(:time)
        )
      else
        last = work_log.last_event
        WorkingDayStatus.new(
          state: work_log.state,
          start_time: work_log.start_time,
          now: @now,
          break_minutes: break_minutes_for_log(work_log),
          expected_minutes: expected_minutes,
          lunch_taken: work_log.lunch_taken?,
          other_days_overtime_minutes: other_days_overtime_minutes,
          remaining_lunch_break_minutes: remaining_lunch_break_minutes(work_log),
          last_event: last&.dig(:event),
          last_event_time: last&.dig(:time)
        )
      end
    end

    def set_hours(hours, date: @now.to_date)
      @overrides[date] = hours
      save_overrides
    end

    def adjust(new_time)
      raise OutsideWorkingHoursError if state == :unstarted

      today_events = events_for_date(@now.to_date)

      if today_events.size > 1
        previous_time = today_events[-2][:time]
        raise InvalidAdjustmentError if new_time < previous_time
      end

      today_events.last[:time] = new_time
      save_events
    end

    def month_statistics
      dates = @events.map { |e| e[:date] }.uniq.sort
      days = dates.map do |date|
        work_log = work_log_for_date(date)
        work_mins = work_minutes_for_log(work_log)
        expected_mins = expected_minutes_for_date(date)
        DayStats.new(
          date: date,
          work_minutes: work_mins,
          expected_minutes: expected_mins,
          overtime_minutes: work_mins - expected_mins
        )
      end
      MonthStats.new(days: days, total_overtime_minutes: days.sum(&:overtime_minutes))
    end

    private

    def work_log_for_date(date)
      WorkLog.new(events: events_for_date(date), date: date)
    end

    def break_minutes_for_log(work_log)
      work_log.breaks.sum { |b| b.duration_minutes || 0 }
    end

    def work_minutes_for_log(work_log)
      return 0 unless work_log.start_time && work_log.stop_time

      total = ((work_log.stop_time - work_log.start_time) / 60).to_i
      total - break_minutes_for_log(work_log)
    end

    def remaining_lunch_break_minutes(work_log)
      lunch = work_log.lunch_break
      return 60 unless lunch

      if lunch.ongoing?
        elapsed = ((@now - lunch.start_time) / 60).to_i
        60 - elapsed
      else
        60 - lunch.duration_minutes
      end
    end

    def other_days_overtime_minutes
      month_statistics.days
        .reject { |d| d.date == @now.to_date }
        .sum(&:overtime_minutes)
    end

    def month_overtime_minutes
      month_statistics.total_overtime_minutes
    end

    def expected_minutes
      expected_minutes_for_date(@now.to_date)
    end

    def expected_minutes_for_date(date)
      hours = @overrides.fetch(date, 8)
      hours * 60
    end

    def state
      work_log_for_date(@now.to_date).state
    end

    def outside_working_hours?
      %i[stopped unstarted].include?(state)
    end

    def lunch_taken?
      work_log_for_date(@now.to_date).lunch_taken?
    end

    def events_for_date(date)
      @events.select { |e| e[:date] == date }
    end

    def record_event(event_type)
      @events << { date: @now.to_date, event: event_type, time: @now.strftime("%H:%M") }
      save_events
    end

    def resume_after_stop
      stop_event = @events.find { |e| e[:date] == @now.to_date && e[:event] == :stop }
      stop_time = stop_event[:time]

      @events.delete(stop_event)
      @events << { date: @now.to_date, event: :break_start, time: stop_time }
      @events << { date: @now.to_date, event: :break_end, time: @now.strftime("%H:%M") }
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
