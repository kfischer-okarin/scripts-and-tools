# frozen_string_literal: true

require "fileutils"
require "json"
require "tmpdir"

module WithSecureEnv
  class EnvEditor
    def edit(current_envs)
      Dir.mktmpdir("with-secure-env") do |dir|
        path = File.join(dir, "env.json")
        File.write(path, JSON.pretty_generate(current_envs))

        system(editor, path)

        JSON.parse(File.read(path))
      end
    end

    private

    def editor
      ENV.fetch("EDITOR", "vim")
    end
  end
end
