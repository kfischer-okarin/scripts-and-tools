# frozen_string_literal: true

require "test_helper"
require "json"
require "tmpdir"
require "fileutils"

require "with_secure_env/secure_env_launcher"

class SecureEnvLauncherTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir)
  end

  def test_launches_app_with_envs_and_args_when_access_granted
    process_context = Object.new
    env_storage = StubEnvStorage.new
    access_policy = StubAccessPolicy.new

    launcher = WithSecureEnv::SecureEnvLauncher.new(
      env_storage: env_storage,
      access_policy: access_policy,
      env_editor: StubEnvEditor.new
    )

    captured = with_test_app(capture_envs: ["API_KEY", "SECRET"]) do |test_app_path|
      env_storage.set(test_app_path, { "API_KEY" => "key123", "SECRET" => "secret456" })
      access_policy.expect_check(
        app_path: test_app_path,
        env_keys: ["API_KEY", "SECRET"],
        process_context: process_context
      )
      launcher.launch_application(test_app_path, ["arg1", "arg2"], process_context: process_context)
    end

    assert_equal "key123", captured[:env]["API_KEY"]
    assert_equal "secret456", captured[:env]["SECRET"]
    assert_equal ["arg1", "arg2"], captured[:args]
  end

  def test_raises_permission_denied_when_access_denied_without_accessing_secrets
    env_storage = StubEnvStorage.new
    env_storage.set("/usr/bin/env", { "SECRET_KEY" => "secret_value" })
    access_policy = StubAccessPolicy.new.deny_all

    launcher = WithSecureEnv::SecureEnvLauncher.new(
      env_storage: env_storage,
      access_policy: access_policy,
      env_editor: StubEnvEditor.new
    )

    assert_raises(WithSecureEnv::PermissionDeniedError) do
      launcher.launch_application("/usr/bin/env", [], process_context: nil)
    end

    refute env_storage.secrets_accessed?, "secrets should not be accessed when permission denied"
  end

  def test_edit_envs_saves_updated_envs
    env_storage = StubEnvStorage.new
    env_storage.set("/usr/bin/test", { "OLD_KEY" => "old_value" })
    env_editor = StubEnvEditor.new({ "NEW_KEY" => "new_value" })

    launcher = WithSecureEnv::SecureEnvLauncher.new(
      env_storage: env_storage,
      access_policy: StubAccessPolicy.new,
      env_editor: env_editor
    )

    launcher.edit_envs("/usr/bin/test")

    assert_equal({ "OLD_KEY" => "old_value" }, env_editor.received_current_envs)
    assert_equal({ "NEW_KEY" => "new_value" }, env_storage.get("/usr/bin/test"))
  end

  def test_edit_envs_does_not_save_when_cancelled
    env_storage = StubEnvStorage.new
    env_storage.set("/usr/bin/test", { "OLD_KEY" => "old_value" })
    env_editor = StubEnvEditor.new(nil)

    launcher = WithSecureEnv::SecureEnvLauncher.new(
      env_storage: env_storage,
      access_policy: StubAccessPolicy.new,
      env_editor: env_editor
    )

    launcher.edit_envs("/usr/bin/test")

    assert_equal({ "OLD_KEY" => "old_value" }, env_storage.get("/usr/bin/test"))
  end

  def test_raises_unknown_app_when_no_envs_configured
    env_storage = StubEnvStorage.new
    access_policy = StubAccessPolicy.new

    launcher = WithSecureEnv::SecureEnvLauncher.new(
      env_storage: env_storage,
      access_policy: access_policy,
      env_editor: StubEnvEditor.new
    )

    assert_raises(WithSecureEnv::UnknownAppError) do
      launcher.launch_application("/unknown/app", [], process_context: nil)
    end
  end

  def test_init_initializes_storage
    env_storage = StubEnvStorage.new

    launcher = WithSecureEnv::SecureEnvLauncher.new(
      env_storage: env_storage,
      access_policy: StubAccessPolicy.new,
      env_editor: StubEnvEditor.new
    )

    launcher.init

    assert env_storage.initialized?
  end

  def test_list_applications_returns_configured_apps
    env_storage = StubEnvStorage.new
    env_storage.set("/usr/bin/app1", { "KEY" => "val" })
    env_storage.set("/usr/bin/app2", { "KEY" => "val" })

    launcher = WithSecureEnv::SecureEnvLauncher.new(
      env_storage: env_storage,
      access_policy: StubAccessPolicy.new,
      env_editor: StubEnvEditor.new
    )

    assert_equal ["/usr/bin/app1", "/usr/bin/app2"], launcher.list_applications.sort
  end

  def test_list_env_keys_returns_keys_for_app
    env_storage = StubEnvStorage.new
    env_storage.set("/usr/bin/app", { "API_KEY" => "secret", "TOKEN" => "value" })

    launcher = WithSecureEnv::SecureEnvLauncher.new(
      env_storage: env_storage,
      access_policy: StubAccessPolicy.new,
      env_editor: StubEnvEditor.new
    )

    assert_equal ["API_KEY", "TOKEN"], launcher.list_env_keys("/usr/bin/app").sort
  end

  def test_remove_deletes_app_config
    env_storage = StubEnvStorage.new
    env_storage.set("/usr/bin/app", { "KEY" => "val" })

    launcher = WithSecureEnv::SecureEnvLauncher.new(
      env_storage: env_storage,
      access_policy: StubAccessPolicy.new,
      env_editor: StubEnvEditor.new
    )

    launcher.remove("/usr/bin/app")

    refute env_storage.app_configured?("/usr/bin/app")
  end

  private

  def with_test_app(capture_envs: [])
    output_file = File.join(@tmp_dir, "output.json")

    script = File.join(@tmp_dir, "test_app.rb")
    File.write(script, <<~RUBY)
      #!/usr/bin/env ruby
      require "json"
      captured_env = #{capture_envs.inspect}.each_with_object({}) do |key, hash|
        hash[key] = ENV[key] if ENV.key?(key)
      end
      File.write(#{output_file.inspect}, JSON.generate({ "env" => captured_env, "args" => ARGV }))
    RUBY
    File.chmod(0o755, script)

    pid = fork do
      yield script
    end
    Process.wait(pid)

    result = JSON.parse(File.read(output_file))
    { env: result["env"], args: result["args"] }
  end

  class StubEnvStorage
    def initialize
      @envs_by_app = {}
      @secrets_accessed = false
      @initialized = false
    end

    def init
      @initialized = true
    end

    def initialized?
      @initialized
    end

    def set(app_path, envs)
      @envs_by_app[app_path] = envs
    end

    def get(app_path)
      @secrets_accessed = true
      @envs_by_app[app_path] || {}
    end

    def secrets_accessed?
      @secrets_accessed
    end

    def available_keys(app_path)
      (@envs_by_app[app_path] || {}).keys
    end

    def app_configured?(app_path)
      @envs_by_app.key?(app_path)
    end

    def list_applications
      @envs_by_app.keys
    end

    def remove(app_path)
      @envs_by_app.delete(app_path)
    end
  end

  class StubEnvEditor
    attr_reader :received_current_envs

    def initialize(return_envs = {})
      @return_envs = return_envs
    end

    def edit(current_envs)
      @received_current_envs = current_envs
      @return_envs
    end
  end

  class StubAccessPolicy
    def initialize
      @allow = true
      @expected = nil
    end

    def expect_check(app_path:, env_keys:, process_context:)
      @expected = { app_path: app_path, env_keys: env_keys.sort, process_context: process_context }
    end

    def deny_all
      @allow = false
      self
    end

    def check(app_path:, env_keys:, process_context:)
      if @expected
        return false unless app_path == @expected[:app_path]
        return false unless env_keys.sort == @expected[:env_keys]
        return false unless process_context == @expected[:process_context]
      end
      @allow
    end
  end
end
