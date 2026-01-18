# frozen_string_literal: true

require "test_helper"
require "tmpdir"
require "fileutils"

require "with_secure_env/env_storage"

class EnvStorageTest < Minitest::Test
  def setup
    @tmp_dir = Dir.mktmpdir
    @secrets_path = File.join(@tmp_dir, "secrets.enc")
    @keychain = StubKeychain.new
  end

  def teardown
    FileUtils.remove_entry(@tmp_dir)
  end

  def test_init_generates_key_stores_in_keychain_and_returns_it
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )

    key = storage.init

    assert @keychain.has_key?
    assert_equal @keychain.get_key, key
    assert File.exist?(@secrets_path)
  end

  def test_init_with_existing_key_uses_that_key
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )
    existing_key = "a" * 64  # 64 hex chars = 32 bytes

    key = storage.init(key: existing_key)

    assert_equal existing_key, @keychain.get_key
    assert_equal existing_key, key
  end

  def test_set_and_get_roundtrip
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )
    storage.init

    storage.set("/usr/bin/app", { "API_KEY" => "secret123" })
    result = storage.get("/usr/bin/app")

    assert_equal({ "API_KEY" => "secret123" }, result)
  end

  def test_get_returns_empty_hash_for_unknown_app
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )
    storage.init

    result = storage.get("/unknown/app")

    assert_equal({}, result)
  end

  def test_app_configured_returns_false_for_unknown_app
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )
    storage.init

    refute storage.app_configured?("/unknown/app")
  end

  def test_app_configured_returns_true_after_set
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )
    storage.init
    storage.set("/usr/bin/app", { "KEY" => "val" })

    assert storage.app_configured?("/usr/bin/app")
  end

  def test_list_applications_returns_all_configured_apps
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )
    storage.init
    storage.set("/usr/bin/app1", { "KEY" => "val" })
    storage.set("/usr/bin/app2", { "KEY" => "val" })

    assert_equal ["/usr/bin/app1", "/usr/bin/app2"], storage.list_applications.sort
  end

  def test_available_keys_returns_env_var_names
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )
    storage.init
    storage.set("/usr/bin/app", { "API_KEY" => "secret", "TOKEN" => "value" })

    assert_equal ["API_KEY", "TOKEN"], storage.available_keys("/usr/bin/app").sort
  end

  def test_remove_deletes_app_config
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )
    storage.init
    storage.set("/usr/bin/app", { "KEY" => "val" })

    storage.remove("/usr/bin/app")

    refute storage.app_configured?("/usr/bin/app")
  end

  def test_file_format_is_readable_json_with_encrypted_values
    storage = WithSecureEnv::EnvStorage.new(
      secrets_path: @secrets_path,
      keychain: @keychain
    )
    storage.init
    storage.set("/usr/bin/app", { "SECRET" => "value123", "API_KEY" => "key456" })

    # File should be readable JSON
    data = JSON.parse(File.read(@secrets_path))

    # Structure should be visible
    assert data.key?("/usr/bin/app")
    assert data["/usr/bin/app"].key?("SECRET")
    assert data["/usr/bin/app"].key?("API_KEY")

    # Each value should be a single base64 string
    secret_entry = data["/usr/bin/app"]["SECRET"]
    assert_kind_of String, secret_entry

    # Should be able to decrypt manually: iv (12) + tag (16) + ciphertext
    raw = Base64.decode64(secret_entry)
    iv = raw[0, 12]
    tag = raw[12, 16]
    ciphertext = raw[28..]

    cipher = OpenSSL::Cipher.new("aes-256-gcm")
    cipher.decrypt
    cipher.iv = iv
    cipher.key = [@keychain.get_key].pack("H*")
    cipher.auth_tag = tag

    plaintext = cipher.update(ciphertext) + cipher.final
    assert_equal "value123", plaintext
  end

  class StubKeychain
    def initialize
      @key = nil
    end

    def store_key(key)
      @key = key
    end

    def get_key
      @key or raise "No key stored"
    end

    def has_key?
      !@key.nil?
    end
  end
end
