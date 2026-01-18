# frozen_string_literal: true

module WithSecureEnv
  class Keychain
    SERVICE = "with-secure-env"

    def store_key(key)
      system(
        "security", "add-generic-password",
        "-a", SERVICE,
        "-s", SERVICE,
        "-w", key,
        "-U"
      )
    end

    def get_key
      result = `security find-generic-password -a #{SERVICE} -s #{SERVICE} -w 2>/dev/null`.chomp
      raise "No encryption key found in keychain" if result.empty?
      result
    end

    def has_key?
      system(
        "security", "find-generic-password",
        "-a", SERVICE,
        "-s", SERVICE,
        out: File::NULL,
        err: File::NULL
      )
    end
  end
end
