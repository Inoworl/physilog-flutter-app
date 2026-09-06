# frozen_string_literal: true

require 'json'
require 'minitest/autorun'
require 'tempfile'
require_relative 'configure_public_sdk_key'

class RevenueCatPublicSdkKeyTest < Minitest::Test
  def test_configures_platform_key_without_touching_other_values
    file = Tempfile.new(['dart-define', '.json'])
    file.write(JSON.generate({
                               'DATA_STORE_MODE' => 'firestore',
                               'REVENUECAT_ANDROID_API_KEY' => 'existing-android-key'
                             }))
    file.close

    RevenueCatPublicSdkKey.configure!(
      dart_define_path: file.path,
      platform: 'ios',
      api_key: 'appl_public-key'
    )

    values = JSON.parse(File.read(file.path))
    assert_equal 'firestore', values.fetch('DATA_STORE_MODE')
    assert_equal 'appl_public-key', values.fetch('REVENUECAT_IOS_API_KEY')
    assert_equal 'existing-android-key', values.fetch('REVENUECAT_ANDROID_API_KEY')
  ensure
    file&.unlink
  end

  def test_rejects_test_store_key_without_echoing_key
    error = assert_raises(RevenueCatPublicSdkKey::InvalidKeyError) do
      RevenueCatPublicSdkKey.configure!(
        dart_define_path: 'unused.json',
        platform: 'android',
        api_key: 'test_private-value'
      )
    end

    assert_includes error.message, 'Test Store'
    refute_includes error.message, 'test_private-value'
  end

  def test_rejects_secret_api_key_without_echoing_key
    error = assert_raises(RevenueCatPublicSdkKey::InvalidKeyError) do
      RevenueCatPublicSdkKey.configure!(
        dart_define_path: 'unused.json',
        platform: 'ios',
        api_key: 'sk_private-value'
      )
    end

    assert_includes error.message, 'public SDK key'
    refute_includes error.message, 'sk_private-value'
  end

  def test_rejects_missing_key_and_unknown_platform
    assert_raises(RevenueCatPublicSdkKey::InvalidKeyError) do
      RevenueCatPublicSdkKey.configure!(
        dart_define_path: 'unused.json',
        platform: 'ios',
        api_key: ' '
      )
    end
    assert_raises(ArgumentError) do
      RevenueCatPublicSdkKey.configure!(
        dart_define_path: 'unused.json',
        platform: 'web',
        api_key: 'public-key'
      )
    end
  end

  def test_rejects_public_sdk_key_for_another_platform_without_echoing_key
    error = assert_raises(RevenueCatPublicSdkKey::InvalidKeyError) do
      RevenueCatPublicSdkKey.configure!(
        dart_define_path: 'unused.json',
        platform: 'ios',
        api_key: 'goog_private-value'
      )
    end

    assert_includes error.message, 'iOS'
    refute_includes error.message, 'goog_private-value'

    error = assert_raises(RevenueCatPublicSdkKey::InvalidKeyError) do
      RevenueCatPublicSdkKey.configure!(
        dart_define_path: 'unused.json',
        platform: 'android',
        api_key: 'appl_private-value'
      )
    end

    assert_includes error.message, 'Android'
    refute_includes error.message, 'appl_private-value'
  end
end
