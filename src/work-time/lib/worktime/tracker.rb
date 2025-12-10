# frozen_string_literal: true

require "csv"
require "fileutils"
require "time"

module Worktime
  class AlreadyWorkingError < StandardError; end
  class LunchAlreadyTakenError < StandardError; end
  class NotWorkingError < StandardError; end

  class Tracker
    Status = Data.define(:state)

    def initialize(data_dir:, now: Time.now)
      @data_dir = data_dir
      @now = now
      load_events
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
      Status.new(state: state)
    end

    private

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
  end
end
