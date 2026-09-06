#!/usr/bin/env ruby
# frozen_string_literal: true

require 'json'
require 'net/http'
require 'optparse'
require 'uri'
require 'yaml'

module RevenueCatCatalog
  def self.default_api_key_env(env_name)
    case env_name
    when 'dev'
      'REVENUECAT_DEV_SECRET_API_KEY'
    when 'prod'
      'REVENUECAT_PROD_SECRET_API_KEY'
    else
      "REVENUECAT_#{env_name.upcase}_SECRET_API_KEY"
    end
  end

  Operation = Struct.new(:action, :target, :detail, keyword_init: true) do
    def to_s
      [action, target, detail].compact.join(' ')
    end
  end

  class EnvFile
    def self.load(path)
      values = {}
      File.readlines(path).each do |line|
        line = line.strip
        next if line.empty? || line.start_with?('#')

        key, value = line.split('=', 2)
        next if value.nil?

        values[key.strip] = unquote(value.strip)
      end
      values
    end

    def self.unquote(value)
      if value.start_with?("'") && value.end_with?("'")
        value[1...-1]
      elsif value.start_with?('"') && value.end_with?('"')
        value[1...-1]
      else
        value
      end
    end
    private_class_method :unquote
  end

  class Catalog
    SUPPORTED_DURATIONS = %w[P1W P1M P2M P3M P6M P1Y].freeze

    attr_reader :data

    def self.load(path)
      new(YAML.safe_load(File.read(path), aliases: true))
    end

    def initialize(data)
      @data = data || {}
    end

    def environment(name)
      environments.fetch(name) do
        raise ArgumentError, "Unknown environment: #{name}"
      end
    end

    def environments
      data.fetch('environments', {})
    end

    def entitlements
      data.fetch('entitlements', [])
    end

    def products
      data.fetch('products', [])
    end

    def offering
      data.fetch('offering', {})
    end

    def store_products(env_name)
      env = environment(env_name)
      apps = env.fetch('apps', {})

      products.flat_map do |product|
        Array(product.dig('store_products', env_name)).map do |store_product|
          app_key = store_product['app']
          app = apps.fetch(app_key, {})
          product.merge(
            'catalog_product_id' => product['id'],
            'config_id' => "#{product['id']}@#{app_key}",
            'app' => app_key,
            'app_id' => app['app_id'],
            'store' => app['store'],
            'store_identifier' => store_product['store_identifier']
          )
        end
      end
    end

    def store_products_for(env_name, catalog_product_id)
      store_products(env_name).select do |product|
        product.fetch('catalog_product_id') == catalog_product_id
      end
    end

    def validate(env_name)
      errors = []
      env = environments[env_name]
      errors << "Missing environments.#{env_name}" if env.nil?
      errors << "Missing project_id for #{env_name}" if env && blank?(env['project_id'])
      apps = env&.fetch('apps', {}) || {}
      errors << "Missing apps for #{env_name}" if apps.empty?
      apps.each do |app_key, app|
        errors << "Missing app_id for #{env_name}.#{app_key}" if blank?(app['app_id'])
        errors << "Missing store for #{env_name}.#{app_key}" if blank?(app['store'])
      end

      entitlement_ids = entitlements.map { |item| item['id'] }
      duplicate(entitlement_ids).each { |id| errors << "Duplicate entitlement id: #{id}" }
      entitlements.each do |item|
        errors << 'Entitlement id is required' if blank?(item['id'])
        errors << "Entitlement #{item['id']} display_name is required" if blank?(item['display_name'])
      end

      product_ids = products.map { |item| item['id'] }
      duplicate(product_ids).each { |id| errors << "Duplicate product id: #{id}" }
      products.each do |item|
        validate_product(item, entitlement_ids, env_name, apps, errors)
      end
      validate_store_product_uniqueness(env_name, errors) if env

      package_ids = packages.map { |item| item['id'] }
      duplicate(package_ids).each { |id| errors << "Duplicate package id: #{id}" }
      packages.each do |item|
        errors << "Package #{item['id']} references unknown product #{item['product_id']}" unless product_ids.include?(item['product_id'])
      end

      errors
    end

    def packages
      offering.fetch('packages', [])
    end

    private

    def validate_product(item, entitlement_ids, env_name, apps, errors)
      id = item['id']
      errors << 'Product id is required' if blank?(id)
      errors << "Product #{id} display_name is required" if blank?(item['display_name'])
      errors << "Product #{id} title is required" if blank?(item['title'])
      errors << "Product #{id} type must be subscription" unless item['type'] == 'subscription'
      errors << "Product #{id} duration is unsupported" unless SUPPORTED_DURATIONS.include?(item['duration'])
      errors << "Product #{id} references unknown entitlement #{item['entitlement_id']}" unless entitlement_ids.include?(item['entitlement_id'])

      store_products = Array(item.dig('store_products', env_name))
      if store_products.empty?
        errors << "Product #{id} has no store product for #{env_name}"
        return
      end

      store_products.each do |store_product|
        app_key = store_product['app']
        errors << "Product #{id} store app is required for #{env_name}" if blank?(app_key)
        errors << "Product #{id} references unknown app #{app_key} for #{env_name}" unless apps.key?(app_key)
        if blank?(store_product['store_identifier'])
          errors << "Product #{id} store_identifier is required for #{env_name}.#{app_key}"
        end
      end

      configured_apps = store_products.map { |store_product| store_product['app'] }.compact
      (apps.keys - configured_apps).each do |app_key|
        errors << "Product #{id} has no store product for #{env_name}.#{app_key}"
      end
    end

    def validate_store_product_uniqueness(env_name, errors)
      configured_products = store_products(env_name)
      duplicate(configured_products.map { |item| item['config_id'] }).each do |id|
        errors << "Duplicate store product config: #{id}"
      end
      duplicate(configured_products.map { |item| [item['app'], item['store_identifier']] }).each do |app, identifier|
        errors << "Duplicate store product identifier: #{app}.#{identifier}"
      end
    end

    def duplicate(values)
      counts = Hash.new(0)
      values.compact.each { |value| counts[value] += 1 }
      counts.select { |_value, count| count > 1 }.keys
    end

    def blank?(value)
      value.nil? || value.to_s.strip.empty?
    end
  end

  class Api
    BASE_URL = 'https://api.revenuecat.com/v2'

    def initialize(api_key)
      @api_key = api_key
    end

    def list_entitlements(project_id)
      list_all("/projects/#{project_id}/entitlements")
    end

    def create_entitlement(project_id, entitlement)
      post("/projects/#{project_id}/entitlements", {
        lookup_key: entitlement.fetch('id'),
        display_name: entitlement.fetch('display_name')
      })
    end

    def list_products(project_id)
      list_all("/projects/#{project_id}/products")
    end

    def create_product(project_id, app_id, product)
      payload = {
        store_identifier: product.fetch('store_identifier'),
        app_id: app_id,
        type: product.fetch('type'),
        display_name: product.fetch('display_name')
      }
      if product.fetch('store') == 'test_store'
        payload[:title] = product.fetch('title')
        payload[:subscription] = {
          duration: product.fetch('duration')
        }
      end
      post("/projects/#{project_id}/products", payload)
    end

    def list_offerings(project_id)
      list_all("/projects/#{project_id}/offerings")
    end

    def create_offering(project_id, offering)
      post("/projects/#{project_id}/offerings", {
        lookup_key: offering.fetch('id'),
        display_name: offering.fetch('display_name')
      })
    end

    def update_offering(project_id, offering_id, offering)
      post("/projects/#{project_id}/offerings/#{offering_id}", {
        display_name: offering.fetch('display_name'),
        is_current: offering.fetch('current', true)
      })
    end

    def list_packages(project_id, offering_id)
      list_all("/projects/#{project_id}/offerings/#{offering_id}/packages")
    end

    def create_package(project_id, offering_id, package)
      post("/projects/#{project_id}/offerings/#{offering_id}/packages", {
        lookup_key: package.fetch('id'),
        display_name: package.fetch('display_name'),
        position: package.fetch('position')
      })
    end

    def update_package(project_id, package_id, package)
      post("/projects/#{project_id}/packages/#{package_id}", {
        display_name: package.fetch('display_name')
      })
    end

    def list_entitlement_products(project_id, entitlement_id)
      list_all("/projects/#{project_id}/entitlements/#{entitlement_id}/products")
    end

    def attach_products_to_entitlement(project_id, entitlement_id, product_ids)
      post("/projects/#{project_id}/entitlements/#{entitlement_id}/actions/attach_products", {
        product_ids: product_ids
      })
    end

    def list_package_products(project_id, package_id)
      list_all("/projects/#{project_id}/packages/#{package_id}/products")
    end

    def attach_products_to_package(project_id, package_id, product_ids)
      post("/projects/#{project_id}/packages/#{package_id}/actions/attach_products", {
        products: product_ids.map { |id| { product_id: id, eligibility_criteria: 'all' } }
      })
    end

    private

    def list_all(path)
      items = []
      current = path
      loop do
        response = get(current)
        items.concat(response.fetch('items', []))
        current = response['next_page']&.sub(%r{\A/v2}, '')
        break if current.nil? || current.empty?
      end
      items
    end

    def get(path)
      request(Net::HTTP::Get, path)
    end

    def post(path, body)
      request(Net::HTTP::Post, path, body)
    end

    def request(method_class, path, body = nil)
      uri = URI("#{BASE_URL}#{path}")
      request = method_class.new(uri)
      request['Authorization'] = "Bearer #{@api_key}"
      request['Content-Type'] = 'application/json'
      request.body = JSON.generate(body) if body

      response = Net::HTTP.start(uri.hostname, uri.port, use_ssl: true) do |http|
        http.request(request)
      end
      parsed = response.body.nil? || response.body.empty? ? {} : JSON.parse(response.body)
      return parsed if response.code.to_i.between?(200, 299)

      message = parsed['message'] || response.body
      raise "RevenueCat API error #{response.code}: #{message}"
    end
  end

  class Sync
    def initialize(catalog, env_name, api: nil)
      @catalog = catalog
      @env_name = env_name
      @api = api
      @operations = []
    end

    def run(apply:)
      errors = @catalog.validate(@env_name)
      raise ArgumentError, errors.join("\n") unless errors.empty?

      return offline_plan if @api.nil?

      entitlements_by_config_id = ensure_entitlements(apply)
      products_by_config_id = ensure_products(apply)
      offering = ensure_offering(apply)
      packages_by_config_id = ensure_packages(offering, apply)
      ensure_entitlement_product_links(entitlements_by_config_id, products_by_config_id, apply)
      ensure_package_product_links(products_by_config_id, packages_by_config_id, apply)
      @operations
    end

    private

    def offline_plan
      @operations << Operation.new(action: 'validate', target: @env_name, detail: 'catalog is valid')
      @operations << Operation.new(action: 'configure', target: project_id, detail: 'set a RevenueCat secret key for live diff or --apply')
      @operations
    end

    def ensure_entitlements(apply)
      existing = index_by_lookup_key(@api.list_entitlements(project_id))
      @catalog.entitlements.each do |entitlement|
        next if existing.key?(entitlement.fetch('id'))

        record(:create, "entitlement #{entitlement.fetch('id')}", entitlement.fetch('display_name'))
        created = if apply
                    @api.create_entitlement(project_id, entitlement)
                  else
                    planned_entity(entitlement)
                  end
        existing[created.fetch('lookup_key')] = created
      end
      existing
    end

    def ensure_products(apply)
      existing = index_by_store_product(@api.list_products(project_id))
      by_config_id = {}
      @catalog.store_products(@env_name).each do |product|
        key = store_product_key(product.fetch('app_id'), product.fetch('store_identifier'))
        current = existing[key]
        unless current
          record(:create, "product #{product.fetch('config_id')}", price_detail(product))
          current = if apply
                      @api.create_product(project_id, product.fetch('app_id'), product)
                    else
                      {
                        'id' => product.fetch('config_id'),
                        'store_identifier' => product.fetch('store_identifier'),
                        'app_id' => product.fetch('app_id'),
                        'planned' => true
                      }
                    end
          existing[key] = current
        end
        by_config_id[product.fetch('config_id')] = current
      end
      by_config_id
    end

    def ensure_offering(apply)
      offering_config = @catalog.offering
      existing = index_by_lookup_key(@api.list_offerings(project_id))
      offering = existing[offering_config.fetch('id')]
      if offering
        if offering_config.fetch('current', true) && !offering['is_current']
          record(:update, "offering #{offering_config.fetch('id')}", 'mark current')
          offering = @api.update_offering(project_id, offering.fetch('id'), offering_config) if apply
        end
      else
        record(:create, "offering #{offering_config.fetch('id')}", offering_config.fetch('display_name'))
        offering = if apply
                     @api.create_offering(project_id, offering_config)
                   else
                     {
                       'id' => offering_config.fetch('id'),
                       'lookup_key' => offering_config.fetch('id'),
                       'planned' => true
                     }
                   end
      end
      offering
    end

    def ensure_packages(offering, apply)
      existing = offering['planned'] ? {} : index_by_lookup_key(@api.list_packages(project_id, offering.fetch('id')))

      @catalog.packages.each do |package|
        current = existing[package.fetch('id')]
        if current
          next if current['display_name'] == package.fetch('display_name')

          record(:update, "package #{package.fetch('id')}", package.fetch('display_name'))
          existing[package.fetch('id')] = @api.update_package(project_id, current.fetch('id'), package) if apply
        else
          record(:create, "package #{package.fetch('id')}", "position #{package.fetch('position')}")
          created = if apply
                      @api.create_package(project_id, offering.fetch('id'), package)
                    else
                      planned_entity(package)
                    end
          existing[created.fetch('lookup_key')] = created
        end
      end
      existing
    end

    def ensure_entitlement_product_links(entitlements_by_config_id, products_by_config_id, apply)
      @catalog.store_products(@env_name).group_by { |product| product.fetch('entitlement_id') }.each do |entitlement_id, products|
        entitlement = entitlements_by_config_id.fetch(entitlement_id)
        attached = entitlement['planned'] ? [] : @api.list_entitlement_products(project_id, entitlement.fetch('id'))
        attached_keys = attached.map do |item|
          store_product_key(item.fetch('app_id'), item.fetch('store_identifier'))
        end
        missing = products.reject do |product|
          attached_keys.include?(store_product_key(product.fetch('app_id'), product.fetch('store_identifier')))
        end
        next if missing.empty?

        logical_ids = missing.map { |product| product.fetch('catalog_product_id') }.uniq
        record(:attach, "entitlement #{entitlement_id}", logical_ids.join(', '))
        next unless apply

        ids = missing.map { |product| products_by_config_id.fetch(product.fetch('config_id')).fetch('id') }
        @api.attach_products_to_entitlement(project_id, entitlement.fetch('id'), ids)
      end
    end

    def ensure_package_product_links(products_by_config_id, packages_by_config_id, apply)
      @catalog.packages.each do |package|
        actual_package = packages_by_config_id.fetch(package.fetch('id'))
        attached = actual_package['planned'] ? [] : @api.list_package_products(project_id, actual_package.fetch('id'))
        attached_keys = attached.map do |item|
          product = item.fetch('product')
          store_product_key(product.fetch('app_id'), product.fetch('store_identifier'))
        end
        expected = @catalog.store_products_for(@env_name, package.fetch('product_id'))
        missing = expected.reject do |product|
          attached_keys.include?(store_product_key(product.fetch('app_id'), product.fetch('store_identifier')))
        end
        next if missing.empty?

        record(:attach, "package #{package.fetch('id')}", package.fetch('product_id'))
        next unless apply

        product_ids = missing.map do |product|
          products_by_config_id.fetch(product.fetch('config_id')).fetch('id')
        end
        @api.attach_products_to_package(project_id, actual_package.fetch('id'), product_ids)
      end
    end

    def record(action, target, detail = nil)
      @operations << Operation.new(action: action.to_s, target: target, detail: detail)
    end

    def project_id
      environment.fetch('project_id')
    end

    def environment
      @environment ||= @catalog.environment(@env_name)
    end

    def index_by_lookup_key(items)
      items.to_h { |item| [item.fetch('lookup_key'), item] }
    end

    def index_by_store_product(items)
      items.to_h do |item|
        [store_product_key(item.fetch('app_id'), item.fetch('store_identifier')), item]
      end
    end

    def store_product_key(app_id, store_identifier)
      [app_id, store_identifier]
    end

    def planned_entity(config)
      {
        'id' => config.fetch('id'),
        'lookup_key' => config.fetch('id'),
        'display_name' => config['display_name'],
        'position' => config['position'],
        'planned' => true
      }
    end

    def price_detail(product)
      price = product['intended_price']
      return nil unless price

      "intended #{price.fetch('currency')} #{price.fetch('amount')}"
    end
  end
end

if $PROGRAM_NAME == __FILE__
  options = {
    catalog: File.expand_path('revenuecat_catalog.yaml', __dir__),
    env: ENV.fetch('REVENUECAT_ENV', 'dev'),
    api_key_env: nil,
    env_file: nil,
    apply: false
  }

  parser = OptionParser.new do |opts|
    opts.banner = 'Usage: sync_revenuecat_catalog.rb [options]'
    opts.on('--catalog PATH', 'Path to revenuecat_catalog.yaml') { |value| options[:catalog] = value }
    opts.on('--env NAME', 'Environment name: dev or prod') { |value| options[:env] = value }
    opts.on('--env-file PATH', 'Path to a local .env file containing RevenueCat secret keys') { |value| options[:env_file] = value }
    opts.on('--api-key-env NAME', 'Environment variable containing the RevenueCat API v2 secret key') do |value|
      options[:api_key_env] = value
    end
    opts.on('--apply', 'Apply missing RevenueCat catalog configuration') { options[:apply] = true }
    opts.on('--dry-run', 'Validate and print planned changes without writes') { options[:apply] = false }
  end
  parser.parse!

  api_key_env = options[:api_key_env] || RevenueCatCatalog.default_api_key_env(options.fetch(:env))
  env_file_values = options[:env_file] ? RevenueCatCatalog::EnvFile.load(options.fetch(:env_file)) : {}
  api_key = ENV[api_key_env]
  api_key_source = 'shell environment'
  if api_key.nil? || api_key.empty?
    api_key = env_file_values[api_key_env]
    api_key_source = options[:env_file] ? "--env-file #{options.fetch(:env_file)}" : 'not set'
  end

  puts "config: env=#{options.fetch(:env)}"
  puts "config: api_key_env=#{api_key_env}"
  puts "config: env_file=#{options[:env_file] || '(none)'}"
  puts "config: api_key=#{api_key.nil? || api_key.empty? ? 'missing' : "present from #{api_key_source}"}"

  catalog = RevenueCatCatalog::Catalog.load(options.fetch(:catalog))
  api = api_key && !api_key.empty? ? RevenueCatCatalog::Api.new(api_key) : nil
  abort "Missing #{api_key_env} for --apply" if options.fetch(:apply) && api.nil?

  operations = RevenueCatCatalog::Sync.new(catalog, options.fetch(:env), api: api).run(apply: options.fetch(:apply))
  mode = options.fetch(:apply) ? 'applied' : 'dry-run'
  puts "#{mode}: #{options.fetch(:env)}"
  if operations.empty?
    puts 'No changes.'
  else
    operations.each { |operation| puts "- #{operation}" }
  end
end
