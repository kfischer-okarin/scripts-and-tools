# frozen_string_literal: true

module WithSecureEnv
  class PermissionDeniedError < StandardError; end

  class SecureEnvLauncher
    def initialize(env_storage:, access_policy:, env_editor:)
      @env_storage = env_storage
      @access_policy = access_policy
      @env_editor = env_editor
    end

    def launch_application(app_path, args, process_context:)
      envs = @env_storage.get(app_path)
      env_keys = @env_storage.available_keys(app_path)

      allowed = @access_policy.check(
        app_path: app_path,
        env_keys: env_keys,
        process_context: process_context
      )
      raise PermissionDeniedError unless allowed

      exec(envs, app_path, *args)
    end

    def edit_envs(app_path)
      current_envs = @env_storage.get(app_path)
      updated_envs = @env_editor.edit(current_envs)
      @env_storage.set(app_path, updated_envs) if updated_envs
    end
  end
end
