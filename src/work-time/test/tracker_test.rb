# frozen_string_literal: true

require "fileutils"
require "tmpdir"

require "test_helper"

require "worktime/tracker"

class TrackerTest < Minitest::Test
  def setup
    @data_dir = Dir.mktmpdir
    @tracker = Worktime::Tracker.new(data_dir: @data_dir)
  end

  def teardown
    FileUtils.remove_entry(@data_dir)
  end

  def test_initial_state_is_unstarted
    assert_equal :unstarted, @tracker.status.state
  end

  def test_start_work_changes_state_to_working
    @tracker.start

    assert_equal :working, @tracker.status.state
  end

  def test_start_when_already_working_raises
    @tracker.start

    assert_raises(Worktime::AlreadyWorkingError) { @tracker.start }
  end

  def test_stop_work_changes_state_to_stopped
    @tracker.start
    @tracker.stop

    assert_equal :stopped, @tracker.status.state
  end

  def test_stop_when_not_working_raises
    assert_raises(Worktime::OutsideWorkingHoursError) { @tracker.stop }
  end

  def test_generic_break_toggles_to_on_break_state
    @tracker.start
    @tracker.toggle_break

    assert_equal :on_break, @tracker.status.state
  end

  def test_generic_break_toggles_back_to_working
    @tracker.start
    @tracker.toggle_break
    @tracker.toggle_break

    assert_equal :working, @tracker.status.state
  end

  def test_generic_break_when_not_working_raises
    assert_raises(Worktime::OutsideWorkingHoursError) { @tracker.toggle_break }
  end

  def test_lunch_toggles_to_on_lunch_state
    @tracker.start
    @tracker.toggle_lunch

    assert_equal :on_lunch, @tracker.status.state
  end

  def test_lunch_toggles_back_to_working
    @tracker.start
    @tracker.toggle_lunch
    @tracker.toggle_lunch

    assert_equal :working, @tracker.status.state
  end

  def test_lunch_when_not_working_raises
    assert_raises(Worktime::OutsideWorkingHoursError) { @tracker.toggle_lunch }
  end

  def test_lunch_twice_in_same_day_raises
    @tracker.start
    @tracker.toggle_lunch
    @tracker.toggle_lunch

    assert_raises(Worktime::LunchAlreadyTakenError) { @tracker.toggle_lunch }
  end

  def test_stop_auto_ends_generic_break
    @tracker.start
    @tracker.toggle_break
    @tracker.stop

    assert_equal :stopped, @tracker.status.state
  end

  def test_stop_auto_ends_lunch
    @tracker.start
    @tracker.toggle_lunch
    @tracker.stop

    assert_equal :stopped, @tracker.status.state
  end

  def test_state_persists_across_tracker_instances
    @tracker.start

    new_tracker = Worktime::Tracker.new(data_dir: @data_dir)

    assert_equal :working, new_tracker.status.state
  end

  def test_status_shows_work_duration_for_completed_day
    now = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: now)
    tracker.start

    eight_hours_later = Time.new(2024, 12, 10, 17, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: eight_hours_later)
    tracker.stop

    assert_equal 8 * 60, tracker.status.work_minutes
  end

  def test_work_minutes_deducts_lunch_time
    at_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_nine)
    tracker.start

    at_noon = Time.new(2024, 12, 10, 12, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_noon)
    tracker.toggle_lunch

    at_one = Time.new(2024, 12, 10, 13, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_one)
    tracker.toggle_lunch

    at_six = Time.new(2024, 12, 10, 18, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_six)
    tracker.stop

    assert_equal 8 * 60, tracker.status.work_minutes
  end

  def test_work_minutes_deducts_generic_break_time
    at_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_nine)
    tracker.start

    at_ten = Time.new(2024, 12, 10, 10, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_ten)
    tracker.toggle_break

    at_ten_fifteen = Time.new(2024, 12, 10, 10, 15, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_ten_fifteen)
    tracker.toggle_break

    at_five = Time.new(2024, 12, 10, 17, 15, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_five)
    tracker.stop

    assert_equal 8 * 60, tracker.status.work_minutes
  end

  def test_todays_surplus_minutes_when_worked_more_than_expected
    at_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_nine)
    tracker.start

    at_six = Time.new(2024, 12, 10, 18, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_six)
    tracker.stop

    assert_equal 60, tracker.status.todays_surplus_minutes
  end

  def test_set_hours_overrides_expected_hours_for_today
    at_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_nine)
    tracker.set_hours(4)
    tracker.start

    at_one = Time.new(2024, 12, 10, 13, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_one)
    tracker.stop

    assert_equal 0, tracker.status.todays_surplus_minutes
  end

  def test_month_statistics_returns_days_with_work_data
    day1_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day1_nine)
    tracker.start
    day1_five = Time.new(2024, 12, 10, 17, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day1_five)
    tracker.stop

    day2_nine = Time.new(2024, 12, 11, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day2_nine)
    tracker.start
    day2_six = Time.new(2024, 12, 11, 18, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day2_six)
    tracker.stop

    result = tracker.month_statistics

    assert_equal 2, result.days.size
    assert_equal Date.new(2024, 12, 10), result.days[0].date
    assert_equal 8 * 60, result.days[0].work_minutes
    assert_equal 8 * 60, result.days[0].expected_minutes
    assert_equal 0, result.days[0].surplus_minutes
    assert_equal Date.new(2024, 12, 11), result.days[1].date
    assert_equal 9 * 60, result.days[1].work_minutes
    assert_equal 8 * 60, result.days[1].expected_minutes
    assert_equal 60, result.days[1].surplus_minutes
    assert_equal 60, result.total_surplus_minutes
  end

  def test_projected_end_time_after_lunch
    at_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_nine)
    tracker.start

    at_noon = Time.new(2024, 12, 10, 12, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_noon)
    tracker.toggle_lunch

    at_one = Time.new(2024, 12, 10, 13, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_one)
    tracker.toggle_lunch

    at_two = Time.new(2024, 12, 10, 14, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_two)

    assert_equal Time.new(2024, 12, 10, 18, 0, 0), tracker.status.projected_end_time
  end

  def test_projected_end_time_before_lunch_adds_one_hour
    at_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_nine)
    tracker.start

    at_ten = Time.new(2024, 12, 10, 10, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_ten)

    assert_equal Time.new(2024, 12, 10, 18, 0, 0), tracker.status.projected_end_time
  end

  def test_status_has_todays_surplus_and_month_surplus
    day1_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day1_nine)
    tracker.start
    day1_seven = Time.new(2024, 12, 10, 18, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day1_seven)
    tracker.stop

    day2_nine = Time.new(2024, 12, 11, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day2_nine)
    tracker.start
    day2_six = Time.new(2024, 12, 11, 17, 30, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day2_six)
    tracker.stop

    status = tracker.status

    assert_equal 30, status.todays_surplus_minutes
    assert_equal 90, status.month_surplus_minutes
  end

  def test_projected_end_time_until_month_surplus_zero_when_behind
    day1_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day1_nine)
    tracker.start
    day1_four = Time.new(2024, 12, 10, 16, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day1_four)
    tracker.stop

    day2_nine = Time.new(2024, 12, 11, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day2_nine)
    tracker.start

    day2_noon = Time.new(2024, 12, 11, 12, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: day2_noon)

    assert_equal Time.new(2024, 12, 11, 19, 0, 0), tracker.status.projected_end_time_for_zero_surplus
  end

  def test_remaining_lunch_break_minutes_is_60_when_lunch_not_taken
    @tracker.start

    assert_equal 60, @tracker.status.remaining_lunch_break_minutes
  end

  def test_remaining_lunch_break_minutes_is_0_after_60_minute_lunch
    at_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_nine)
    tracker.start

    at_noon = Time.new(2024, 12, 10, 12, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_noon)
    tracker.toggle_lunch

    at_one = Time.new(2024, 12, 10, 13, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_one)
    tracker.toggle_lunch

    assert_equal 0, tracker.status.remaining_lunch_break_minutes
  end

  def test_remaining_lunch_break_minutes_shows_remaining_while_on_lunch
    at_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_nine)
    tracker.start

    at_noon = Time.new(2024, 12, 10, 12, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_noon)
    tracker.toggle_lunch

    at_twelve_fifteen = Time.new(2024, 12, 10, 12, 15, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_twelve_fifteen)

    assert_equal :on_lunch, tracker.status.state
    assert_equal 45, tracker.status.remaining_lunch_break_minutes
  end

  def test_work_minutes_when_stopped_without_ending_lunch
    at_nine = Time.new(2024, 12, 10, 9, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_nine)
    tracker.start

    at_noon = Time.new(2024, 12, 10, 12, 0, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_noon)
    tracker.toggle_lunch

    at_twelve_thirty = Time.new(2024, 12, 10, 12, 30, 0)
    tracker = Worktime::Tracker.new(data_dir: @data_dir, now: at_twelve_thirty)
    tracker.stop

    # 9:00-12:30 = 210 minutes total
    # lunch started at 12:00, stop at 12:30 implicitly ends it (30 min break)
    # work = 210 - 30 = 180
    assert_equal :stopped, tracker.status.state
    assert_equal 180, tracker.status.work_minutes
  end
end

class UnstartedStatusTest < Minitest::Test
  def test_to_json_hash
    status = Worktime::Tracker::UnstartedStatus.new(
      state: :unstarted,
      month_surplus_minutes: 30
    )

    assert_equal({ state: :unstarted, month_surplus_minutes: 30 }, status.to_json_hash)
  end

  def test_to_cli_output
    status = Worktime::Tracker::UnstartedStatus.new(
      state: :unstarted,
      month_surplus_minutes: 30
    )

    expected = <<~OUTPUT.chomp
      State: unstarted
      Month surplus: +0:30
    OUTPUT

    assert_equal expected, status.to_cli_output
  end

  def test_to_cli_output_with_negative_surplus
    status = Worktime::Tracker::UnstartedStatus.new(
      state: :unstarted,
      month_surplus_minutes: -90
    )

    expected = <<~OUTPUT.chomp
      State: unstarted
      Month surplus: -1:30
    OUTPUT

    assert_equal expected, status.to_cli_output
  end
end

class WorkingDayStatusTest < Minitest::Test
  def test_to_json_hash
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    now = Time.new(2024, 12, 10, 13, 0, 0)

    status = Worktime::Tracker::WorkingDayStatus.new(
      state: :working,
      start_time: start_time,
      now: now,
      break_minutes: 0,
      expected_minutes: 480,
      lunch_taken: false,
      other_days_surplus_minutes: 300,
      remaining_lunch_break_minutes: 60
    )

    # work_minutes = 4h = 240, todays_surplus = 240 - 480 = -240
    # month_surplus = 300 + (-240) = 60
    # projected_end_time = now + remaining_work + lunch = 13:00 + 4h + 1h = 18:00
    # projected_end_time_for_zero_surplus = now + (remaining - other_days) + lunch = 13:00 + (4h - 5h) + 1h = 13:00
    expected = {
      state: :working,
      work_minutes: 240,
      todays_surplus_minutes: -240,
      month_surplus_minutes: 60,
      remaining_lunch_break_minutes: 60,
      projected_end_time: Time.new(2024, 12, 10, 18, 0, 0).iso8601,
      projected_end_time_for_zero_surplus: Time.new(2024, 12, 10, 13, 0, 0).iso8601
    }

    assert_equal expected, status.to_json_hash
  end

  def test_to_cli_output
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    now = Time.new(2024, 12, 10, 13, 0, 0)

    status = Worktime::Tracker::WorkingDayStatus.new(
      state: :working,
      start_time: start_time,
      now: now,
      break_minutes: 0,
      expected_minutes: 480,
      lunch_taken: true,
      other_days_surplus_minutes: 300,
      remaining_lunch_break_minutes: 0
    )

    # month_surplus = 300 + (-240) = 60
    # projected_end_time = now + remaining_work = 13:00 + 4h = 17:00 (lunch already taken)
    # projected_end_time_for_zero_surplus = now + (remaining - other_days) = 13:00 + (4h - 5h) = 12:00
    expected = <<~OUTPUT.chomp
      State: working
      Work today: 4:00
      Today's surplus: -4:00
      Month surplus: +1:00
      Remaining lunch: 0m
      Projected end: 17:00
      End for zero surplus: 12:00
    OUTPUT

    assert_equal expected, status.to_cli_output
  end

  def test_work_minutes_is_calculated
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    now = Time.new(2024, 12, 10, 18, 0, 0)

    status = Worktime::Tracker::WorkingDayStatus.new(
      state: :working,
      start_time: start_time,
      now: now,
      break_minutes: 30,
      expected_minutes: 480,
      lunch_taken: true,
      other_days_surplus_minutes: 0,
      remaining_lunch_break_minutes: 0
    )

    assert_equal 510, status.work_minutes
  end

  def test_todays_surplus_minutes_is_calculated
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    now = Time.new(2024, 12, 10, 17, 30, 0)

    status = Worktime::Tracker::WorkingDayStatus.new(
      state: :working,
      start_time: start_time,
      now: now,
      break_minutes: 0,
      expected_minutes: 480,
      lunch_taken: true,
      other_days_surplus_minutes: 0,
      remaining_lunch_break_minutes: 0
    )

    assert_equal 30, status.todays_surplus_minutes
  end

  def test_month_surplus_minutes_is_calculated
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    now = Time.new(2024, 12, 10, 17, 30, 0)

    status = Worktime::Tracker::WorkingDayStatus.new(
      state: :working,
      start_time: start_time,
      now: now,
      break_minutes: 0,
      expected_minutes: 480,
      lunch_taken: true,
      other_days_surplus_minutes: 60,
      remaining_lunch_break_minutes: 0
    )

    # todays_surplus = 30, other_days = 60, month = 90
    assert_equal 90, status.month_surplus_minutes
  end

  def test_projected_end_time_is_calculated
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    now = Time.new(2024, 12, 10, 13, 0, 0)

    status = Worktime::Tracker::WorkingDayStatus.new(
      state: :working,
      start_time: start_time,
      now: now,
      break_minutes: 0,
      expected_minutes: 480,
      lunch_taken: true,
      other_days_surplus_minutes: 0,
      remaining_lunch_break_minutes: 0
    )

    # work_minutes = 4h, remaining = 8h - 4h = 4h, lunch taken so no extra hour
    # projected = 13:00 + 4h = 17:00
    assert_equal Time.new(2024, 12, 10, 17, 0, 0), status.projected_end_time
  end

  def test_projected_end_time_adds_hour_when_lunch_not_taken
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    now = Time.new(2024, 12, 10, 11, 0, 0)

    status = Worktime::Tracker::WorkingDayStatus.new(
      state: :working,
      start_time: start_time,
      now: now,
      break_minutes: 0,
      expected_minutes: 480,
      lunch_taken: false,
      other_days_surplus_minutes: 0,
      remaining_lunch_break_minutes: 60
    )

    # work_minutes = 2h, remaining = 8h - 2h = 6h, lunch not taken so +1h
    # projected = 11:00 + 6h + 1h = 18:00
    assert_equal Time.new(2024, 12, 10, 18, 0, 0), status.projected_end_time
  end

  def test_projected_end_time_for_zero_surplus_is_calculated
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    now = Time.new(2024, 12, 10, 13, 0, 0)

    status = Worktime::Tracker::WorkingDayStatus.new(
      state: :working,
      start_time: start_time,
      now: now,
      break_minutes: 0,
      expected_minutes: 480,
      lunch_taken: true,
      other_days_surplus_minutes: -60,
      remaining_lunch_break_minutes: 0
    )

    # work_minutes = 4h, remaining = 4h, other_days = -1h (behind)
    # remaining_for_zero = 4h - (-1h) = 5h
    # projected = 13:00 + 5h = 18:00
    assert_equal Time.new(2024, 12, 10, 18, 0, 0), status.projected_end_time_for_zero_surplus
  end

  def test_projected_end_time_for_zero_surplus_with_positive_surplus
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    now = Time.new(2024, 12, 10, 13, 0, 0)

    status = Worktime::Tracker::WorkingDayStatus.new(
      state: :working,
      start_time: start_time,
      now: now,
      break_minutes: 0,
      expected_minutes: 480,
      lunch_taken: true,
      other_days_surplus_minutes: 60,
      remaining_lunch_break_minutes: 0
    )

    # work_minutes = 4h, remaining = 4h, other_days = +1h (ahead)
    # remaining_for_zero = 4h - 1h = 3h
    # projected = 13:00 + 3h = 16:00
    assert_equal Time.new(2024, 12, 10, 16, 0, 0), status.projected_end_time_for_zero_surplus
  end
end

class FinishedDayStatusTest < Minitest::Test
  def test_to_json_hash
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    stop_time = Time.new(2024, 12, 10, 17, 0, 0)

    status = Worktime::Tracker::FinishedDayStatus.new(
      state: :stopped,
      start_time: start_time,
      stop_time: stop_time,
      break_minutes: 0,
      expected_minutes: 480,
      other_days_surplus_minutes: 30
    )

    expected = {
      state: :stopped,
      work_minutes: 480,
      todays_surplus_minutes: 0,
      month_surplus_minutes: 30
    }

    assert_equal expected, status.to_json_hash
  end

  def test_to_cli_output
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    stop_time = Time.new(2024, 12, 10, 18, 30, 0)

    status = Worktime::Tracker::FinishedDayStatus.new(
      state: :stopped,
      start_time: start_time,
      stop_time: stop_time,
      break_minutes: 60,
      expected_minutes: 480,
      other_days_surplus_minutes: 60
    )

    # work_minutes = 9.5h - 1h = 8.5h = 510, todays_surplus = 30
    # month_surplus = 60 + 30 = 90
    expected = <<~OUTPUT.chomp
      State: stopped
      Work today: 8:30
      Today's surplus: +0:30
      Month surplus: +1:30
    OUTPUT

    assert_equal expected, status.to_cli_output
  end

  def test_work_minutes_is_calculated
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    stop_time = Time.new(2024, 12, 10, 18, 0, 0)

    status = Worktime::Tracker::FinishedDayStatus.new(
      state: :stopped,
      start_time: start_time,
      stop_time: stop_time,
      break_minutes: 60,
      expected_minutes: 480,
      other_days_surplus_minutes: 0
    )

    assert_equal 480, status.work_minutes
  end

  def test_todays_surplus_minutes_is_calculated
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    stop_time = Time.new(2024, 12, 10, 17, 30, 0)

    status = Worktime::Tracker::FinishedDayStatus.new(
      state: :stopped,
      start_time: start_time,
      stop_time: stop_time,
      break_minutes: 60,
      expected_minutes: 480,
      other_days_surplus_minutes: 0
    )

    assert_equal(-30, status.todays_surplus_minutes)
  end

  def test_month_surplus_minutes_is_calculated
    start_time = Time.new(2024, 12, 10, 9, 0, 0)
    stop_time = Time.new(2024, 12, 10, 17, 30, 0)

    status = Worktime::Tracker::FinishedDayStatus.new(
      state: :stopped,
      start_time: start_time,
      stop_time: stop_time,
      break_minutes: 0,
      expected_minutes: 480,
      other_days_surplus_minutes: 60
    )

    # work = 8.5h = 510, todays_surplus = 30, other_days = 60, month = 90
    assert_equal 90, status.month_surplus_minutes
  end
end
