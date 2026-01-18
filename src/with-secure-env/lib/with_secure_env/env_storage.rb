# frozen_string_literal: true

require "base64"
require "fileutils"
require "json"
require "openssl"
require "securerandom"

module WithSecureEnv
  class EnvStorage
    def initialize(secrets_path:, keychain:)
      @secrets_path = secrets_path
      @keychain = keychain
    end

    def init(key: nil)
      encryption_key = key || generate_key
      @keychain.store_key(encryption_key)
      write_file({})
      encryption_key
    end

    def get(app_path)
      file_data = read_file
      encrypted_envs = file_data[app_path] || {}
      encrypted_envs.transform_values { |blob| decrypt_value(blob) }
    end

    def set(app_path, envs)
      file_data = read_file
      file_data[app_path] = envs.transform_values { |value| encrypt_value(value) }
      write_file(file_data)
    end

    def app_configured?(app_path)
      read_file.key?(app_path)
    end

    def available_keys(app_path)
      (read_file[app_path] || {}).keys
    end

    def list_applications
      read_file.keys
    end

    def remove(app_path)
      file_data = read_file
      file_data.delete(app_path)
      write_file(file_data)
    end

    private

    def generate_key
      SecureRandom.hex(32)
    end

    def read_file
      JSON.parse(File.read(@secrets_path))
    end

    def write_file(data)
      FileUtils.mkdir_p(File.dirname(@secrets_path))
      File.write(@secrets_path, JSON.pretty_generate(data))
      File.chmod(0o600, @secrets_path)
    end

    def encrypt_value(plaintext)
      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.encrypt
      iv = cipher.random_iv
      cipher.key = key_bytes
      ciphertext = cipher.update(plaintext) + cipher.final
      Base64.strict_encode64(iv + cipher.auth_tag + ciphertext)
    end

    def decrypt_value(blob)
      raw = Base64.decode64(blob)
      iv = raw[0, 12]
      tag = raw[12, 16]
      ciphertext = raw[28..]

      cipher = OpenSSL::Cipher.new("aes-256-gcm")
      cipher.decrypt
      cipher.iv = iv
      cipher.key = key_bytes
      cipher.auth_tag = tag
      cipher.update(ciphertext) + cipher.final
    end

    def key_bytes
      [@keychain.get_key].pack("H*")
    end
  end
end
