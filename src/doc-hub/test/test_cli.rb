# frozen_string_literal: true

require_relative 'test_helper'

class TestCLI < Minitest::Test
  def setup
    @original_xdg_data_home = ENV['XDG_DATA_HOME']
    @original_home = ENV['HOME']
  end

  def teardown
    ENV['XDG_DATA_HOME'] = @original_xdg_data_home
    ENV['HOME'] = @original_home
  end

  def test_storage_path_with_xdg_data_home_set
    ENV['XDG_DATA_HOME'] = '/custom/data'

    cli = CLI.new
    expected_path = '/custom/data/doc-hub'
    assert_equal expected_path, cli.storage_path
  end

  def test_storage_path_without_xdg_data_home
    ENV.delete('XDG_DATA_HOME')

    cli = CLI.new
    expected_path = File.join(Dir.home, '.local', 'share', 'doc-hub')
    assert_equal expected_path, cli.storage_path
  end
end
