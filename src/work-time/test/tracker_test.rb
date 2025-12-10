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
    assert_raises(Worktime::NotWorkingError) { @tracker.stop }
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
    assert_raises(Worktime::NotWorkingError) { @tracker.toggle_break }
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
    assert_raises(Worktime::NotWorkingError) { @tracker.toggle_lunch }
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
end
