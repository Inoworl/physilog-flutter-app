#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'optparse'

module RevenueCatPublicSdkKey
  DART_DEFINE_KEYS = {
    'ios' => 'REVENUECAT_IOS_API_KEY',
    'android' => 'REVENUECAT_ANDROID_API_KEY'
  }.freeze
  PUBLIC_KEY_PREFIXES = {
    'ios' => ['appl_', 'iOS'],
    'android' => ['goog_', 'Android']
  }.freeze

  class InvalidKeyError < StandardError; end

  def self.configure!(dart_define_path:, platform:, api_key:)
    dart_define_key = DART_DEFINE_KEYS.fetch(platform) do
      raise ArgumentError, "Unsupported RevenueCat platform: #{platform}"
    end
    validated_key = validate!(api_key, platform: platform)
    values = JSON.parse(File.read(dart_define_path))
    values[dart_define_key] = validated_key
    File.write(dart_define_path, "#{JSON.pretty_generate(values)}\n")
  end

  def self.validate!(api_key, platform:)
    normalized_key = api_key.to_s.strip
    raise InvalidKeyError, 'RevenueCat public SDK key is required' if normalized_key.empty?

    if normalized_key.start_with?('test_')
      raise InvalidKeyError,
            'RevenueCat Test Store key cannot be used in a distributed build'
    end
    if normalized_key.start_with?('sk_')
      raise InvalidKeyError,
            'RevenueCat secret API key cannot be used as a public SDK key'
    end

    expected_prefix, platform_name = PUBLIC_KEY_PREFIXES.fetch(platform)
    unless normalized_key.start_with?(expected_prefix)
      raise InvalidKeyError,
            "RevenueCat #{platform_name} public SDK key has an unexpected format"
    end

    normalized_key
  end
  private_class_method :validate!
end

if $PROGRAM_NAME == __FILE__
  begin
    options = {}
    parser = OptionParser.new do |opts|
      opts.banner = 'Usage: configure_public_sdk_key.rb [options]'
      opts.on('--dart-define PATH', 'Path to the decoded dart-define JSON') do |value|
        options[:dart_define] = value
      end
      opts.on('--platform NAME', 'RevenueCat platform: ios or android') do |value|
        options[:platform] = value
      end
      opts.on('--api-key-env NAME', 'Environment variable containing the public SDK key') do |value|
        options[:api_key_env] = value
      end
    end
    parser.parse!

    required_options = %i[dart_define platform api_key_env]
    missing_options = required_options.reject { |name| options.key?(name) }
    unless missing_options.empty?
      warn "Missing required options: #{missing_options.join(', ')}"
      exit 1
    end

    RevenueCatPublicSdkKey.configure!(
      dart_define_path: options.fetch(:dart_define),
      platform: options.fetch(:platform),
      api_key: ENV[options.fetch(:api_key_env)]
    )
    puts "Configured RevenueCat public SDK key for #{options.fetch(:platform)}."
  rescue RevenueCatPublicSdkKey::InvalidKeyError, ArgumentError, Errno::ENOENT,
         JSON::ParserError => e
    warn "::error ::#{e.message}"
    exit 1
  end
end
