# frozen_string_literal: true

module Worktime
  class WorkLog
    Break = Data.define(:start_time, :end_time) do
      def duration_minutes
        return nil unless end_time
        ((end_time - start_time) / 60).to_i
      end

      def ongoing?
        end_time.nil?
      end
    end

    attr_reader :date

    def initialize(events:, date:)
      @events = events
      @date = date
    end

    def state
      return :unstarted if @events.empty?

      case last_event[:event]
      when :start, :break_end, :lunch_end then :working
      when :stop then :stopped
      when :break_start then :on_break
      when :lunch_start then :on_lunch
      else :stopped
      end
    end

    def start_time
      start_event = @events.find { |e| e[:event] == :start }
      return nil unless start_event

      parse_time(start_event[:time])
    end

    def stop_time
      stop_event = @events.find { |e| e[:event] == :stop }
      return nil unless stop_event

      parse_time(stop_event[:time])
    end

    def lunch_taken?
      @events.any? { |e| e[:event] == :lunch_end }
    end

    def lunch_break
      lunch_start = @events.find { |e| e[:event] == :lunch_start }
      return nil unless lunch_start

      lunch_end = @events.find { |e| e[:event] == :lunch_end }
      Break.new(
        start_time: parse_time(lunch_start[:time]),
        end_time: lunch_end ? parse_time(lunch_end[:time]) : nil
      )
    end

    def breaks
      result = []
      break_start = nil

      @events.each do |event|
        case event[:event]
        when :break_start, :lunch_start
          break_start = parse_time(event[:time])
        when :break_end, :lunch_end, :stop
          result << Break.new(start_time: break_start, end_time: parse_time(event[:time])) if break_start
          break_start = nil
        end
      end

      result << Break.new(start_time: break_start, end_time: nil) if break_start
      result
    end

    def last_event
      @events.last
    end

    private

    def parse_time(time_str)
      hour, min = time_str.split(":").map(&:to_i)
      Time.new(@date.year, @date.month, @date.day, hour, min, 0)
    end
  end
end
