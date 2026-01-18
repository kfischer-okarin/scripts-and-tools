# frozen_string_literal: true

require "thor"

require_relative "env_editor"
require_relative "env_storage"
require_relative "keychain"
require_relative "secure_env_launcher"

module WithSecureEnv
  class CLI < Thor
    def self.exit_on_failure?
      true
    end

    desc "init", "Initialize storage, returns key for backup"
    def init
      key = launcher.init
      puts "Initialized. Save this key in your password manager:"
      puts key
    rescue AlreadyInitializedError => e
      warn "Already initialized: #{e.message}"
      warn "Remove the file manually if you want to reinitialize."
      exit 1
    end

    desc "edit BINARY", "Edit environment variables for a binary"
    def edit(binary)
      launcher.edit_envs(binary)
      puts "Saved environment variables for #{binary}"
    end

    desc "list [BINARY]", "List configured binaries, or env var names for a binary"
    def list(binary = nil)
      if binary
        keys = launcher.list_env_keys(binary)
        if keys.empty?
          puts "No environment variables configured for #{binary}"
        else
          keys.each { |k| puts k }
        end
      else
        apps = launcher.list_applications
        if apps.empty?
          puts "No applications configured"
        else
          apps.each { |app| puts app }
        end
      end
    end

    desc "remove BINARY", "Remove all env vars for a binary"
    def remove(binary)
      launcher.remove(binary)
      puts "Removed configuration for #{binary}"
    end

    desc "exec BINARY [ARGS...]", "Run binary with injected env vars"
    def exec(binary, *args)
      launcher.launch_application(binary, args, process_context: nil)
    rescue UnknownAppError
      warn "No configuration for #{binary}. Use 'edit' first."
      exit 1
    rescue PermissionDeniedError
      warn "Permission denied"
      exit 1
    end

    private

    def launcher
      @launcher ||= SecureEnvLauncher.new(
        env_storage: env_storage,
        access_policy: allow_all_policy,
        env_editor: EnvEditor.new
      )
    end

    def env_storage
      @env_storage ||= EnvStorage.new(
        secrets_path: secrets_path,
        keychain: Keychain.new
      )
    end

    def secrets_path
      File.join(data_dir, "secrets.enc")
    end

    def data_dir
      ENV.fetch("WITH_SECURE_ENV_DATA_DIR") { File.join(xdg_data_home, "with-secure-env") }
    end

    def xdg_data_home
      ENV.fetch("XDG_DATA_HOME") { File.expand_path("~/.local/share") }
    end

    def allow_all_policy
      policy = Object.new
      def policy.check(...) = true
      policy
    end
  end
end
