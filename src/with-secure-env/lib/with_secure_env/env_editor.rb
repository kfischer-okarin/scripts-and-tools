# frozen_string_literal: true

require "json"
require "tempfile"

module WithSecureEnv
  class EnvEditor
    def edit(current_envs)
      Tempfile.create(["env", ".json"]) do |f|
        f.write(JSON.pretty_generate(current_envs))
        f.flush

        system(editor, f.path)

        f.rewind
        JSON.parse(f.read)
      end
    end

    private

    def editor
      ENV.fetch("EDITOR", "vim")
    end
  end
end
