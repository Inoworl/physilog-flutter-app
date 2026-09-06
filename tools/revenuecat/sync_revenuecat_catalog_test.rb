# frozen_string_literal: true

require 'minitest/autorun'
require 'open3'
require 'rbconfig'
require 'tempfile'
require_relative 'sync_revenuecat_catalog'

class RevenueCatCatalogSyncTest < Minitest::Test
  def test_catalog_contains_prod_and_dev_projects
    catalog = RevenueCatCatalog::Catalog.load(File.expand_path('revenuecat_catalog.yaml', __dir__))

    assert_empty catalog.validate('dev')
    assert_empty catalog.validate('prod')
    assert_equal 'b9208054', catalog.environment('dev').fetch('project_id')
    assert_equal 'ec10fe6b', catalog.environment('prod').fetch('project_id')
    assert_equal %w[android ios test_store], catalog.environment('dev').fetch('apps').keys.sort
    assert_equal %w[android ios], catalog.environment('prod').fetch('apps').keys.sort
    assert_equal 12, catalog.store_products('dev').length
    assert_equal 8, catalog.store_products('prod').length
    assert_includes(
      catalog.store_products('dev').map { |product| product.fetch('store_identifier') },
      'com.inoworl.physilog.dev.personal_family.monthly'
    )
    assert_includes(
      catalog.store_products('dev').map { |product| product.fetch('store_identifier') },
      'personal_family:monthly'
    )
    assert_includes(
      catalog.store_products('prod').map { |product| product.fetch('store_identifier') },
      'personal_family:monthly'
    )
    assert_includes(
      catalog.store_products('prod').map { |product| product.fetch('store_identifier') },
      'com.inoworl.physilog.personal_family.monthly'
    )
  end

  def test_default_api_key_env_name_is_based_on_target_environment
    assert_equal 'REVENUECAT_DEV_SECRET_API_KEY', RevenueCatCatalog.default_api_key_env('dev')
    assert_equal 'REVENUECAT_PROD_SECRET_API_KEY', RevenueCatCatalog.default_api_key_env('prod')
  end

  def test_catalog_rejects_a_product_missing_from_a_configured_app
    data = YAML.safe_load(
      File.read(File.expand_path('revenuecat_catalog.yaml', __dir__)),
      aliases: true
    )
    data.fetch('products').first.fetch('store_products').fetch('dev').reject! do |product|
      product.fetch('app') == 'android'
    end

    errors = RevenueCatCatalog::Catalog.new(data).validate('dev')

    assert_includes(
      errors,
      'Product personal_family_monthly has no store product for dev.android'
    )
  end

  def test_env_file_loader_reads_values_without_exposing_them
    file = Tempfile.new('revenuecat-env')
    file.write <<~ENV_FILE
      # comment
      REVENUECAT_DEV_SECRET_API_KEY='sk_dev_secret'
      REVENUECAT_PROD_SECRET_API_KEY="sk_prod_secret"
    ENV_FILE
    file.close

    values = RevenueCatCatalog::EnvFile.load(file.path)

    assert_equal 'sk_dev_secret', values.fetch('REVENUECAT_DEV_SECRET_API_KEY')
    assert_equal 'sk_prod_secret', values.fetch('REVENUECAT_PROD_SECRET_API_KEY')
  ensure
    file&.unlink
  end

  def test_cli_does_not_print_the_env_file_path
    file = Tempfile.new('revenuecat-private-env')
    file.write("UNRELATED=value\n")
    file.close

    output, status = Open3.capture2e(
      RbConfig.ruby,
      File.expand_path('sync_revenuecat_catalog.rb', __dir__),
      '--env',
      'dev',
      '--env-file',
      file.path,
      '--dry-run'
    )

    assert status.success?, output
    assert_includes output, 'config: env_file=provided'
    refute_includes output, file.path
  ensure
    file&.unlink
  end

  def test_dry_run_plans_missing_catalog_items
    catalog = RevenueCatCatalog::Catalog.load(File.expand_path('revenuecat_catalog.yaml', __dir__))
    operations = RevenueCatCatalog::Sync.new(catalog, 'dev', api: FakeRevenueCatApi.new).run(apply: false)
    text = operations.map(&:to_s)

    assert_includes text, 'create entitlement personal_family Personal Family'
    assert_includes text, 'create product team_yearly@test_store intended JPY 8980'
    assert_includes text, 'create offering default Default'
    assert_includes text, 'create package personal_family_monthly position 1'
    assert_includes text, 'attach entitlement team team_monthly, team_yearly'
    assert_includes text, 'attach package team_yearly team_yearly'
  end

  def test_dev_apply_creates_and_attaches_catalog_items_for_all_stores
    api = FakeRevenueCatApi.new
    catalog = RevenueCatCatalog::Catalog.load(File.expand_path('revenuecat_catalog.yaml', __dir__))

    RevenueCatCatalog::Sync.new(catalog, 'dev', api: api).run(apply: true)

    assert_equal %w[personal_family team], api.entitlements.map { |item| item.fetch('lookup_key') }
    assert_equal 12, api.products.length
    expected_app_ids = catalog.environment('dev').fetch('apps').values.map { |app| app.fetch('app_id') }.sort
    assert_equal(
      expected_app_ids,
      api.created_product_payloads.map { |payload| payload.fetch(:app_id) }.uniq.sort
    )
    test_store_payloads = api.created_product_payloads.select { |payload| payload.key?(:title) }
    assert_equal 4, test_store_payloads.length
    assert test_store_payloads.all? { |payload| payload.fetch(:subscription).keys == [:duration] }
    assert_equal 12, api.package_products.values.flatten.length
  end

  def test_prod_apply_creates_both_store_products_and_attaches_equivalents_to_each_package
    api = FakeRevenueCatApi.new
    catalog = RevenueCatCatalog::Catalog.load(File.expand_path('revenuecat_catalog.yaml', __dir__))

    RevenueCatCatalog::Sync.new(catalog, 'prod', api: api).run(apply: true)

    assert_equal 8, api.products.length
    expected_app_ids = catalog.environment('prod').fetch('apps').values.map { |app| app.fetch('app_id') }.sort
    assert_equal(
      expected_app_ids,
      api.created_product_payloads.map { |payload| payload.fetch(:app_id) }.uniq.sort
    )
    assert_equal(
      [
        'com.inoworl.physilog.personal_family.monthly',
        'personal_family:monthly'
      ],
      api.package_products
        .fetch('pkg_personal_family_monthly')
        .map { |item| item.fetch('product').fetch('store_identifier') }
        .sort
    )
  end

  def test_product_api_sends_test_store_subscription_metadata_only_to_test_store
    api = RecordingRevenueCatApi.new
    base_product = {
      'store_identifier' => 'personal_family_monthly',
      'type' => 'subscription',
      'display_name' => 'Personal Family Monthly',
      'title' => 'Personal Family Monthly',
      'duration' => 'P1M'
    }

    api.create_product(
      'project-id',
      'test-store-app',
      base_product.merge('store' => 'test_store')
    )
    api.create_product(
      'project-id',
      'app-store-app',
      base_product.merge(
        'store' => 'app_store',
        'store_identifier' => 'com.inoworl.physilog.personal_family.monthly'
      )
    )

    assert_equal(
      {
        store_identifier: 'personal_family_monthly',
        app_id: 'test-store-app',
        type: 'subscription',
        display_name: 'Personal Family Monthly',
        title: 'Personal Family Monthly',
        subscription: {duration: 'P1M'}
      },
      api.requests.fetch(0).fetch(:body)
    )
    assert_equal(
      {
        store_identifier: 'com.inoworl.physilog.personal_family.monthly',
        app_id: 'app-store-app',
        type: 'subscription',
        display_name: 'Personal Family Monthly'
      },
      api.requests.fetch(1).fetch(:body)
    )
  end

  class RecordingRevenueCatApi < RevenueCatCatalog::Api
    attr_reader :requests

    def initialize
      super('unused-test-key')
      @requests = []
    end

    private

    def post(path, body)
      requests << {path: path, body: body}
      {'id' => 'created-product'}
    end
  end

  class FakeRevenueCatApi
    attr_reader :created_product_payloads, :entitlements, :products, :offerings, :packages, :package_products

    def initialize
      @created_product_payloads = []
      @entitlements = []
      @products = []
      @offerings = []
      @packages = []
      @entitlement_products = Hash.new { |hash, key| hash[key] = [] }
      @package_products = Hash.new { |hash, key| hash[key] = [] }
    end

    def list_entitlements(_project_id)
      entitlements
    end

    def create_entitlement(_project_id, entitlement)
      entitlements << {
        'id' => "ent_#{entitlement.fetch('id')}",
        'lookup_key' => entitlement.fetch('id'),
        'display_name' => entitlement.fetch('display_name')
      }
      entitlements.last
    end

    def list_products(_project_id)
      products
    end

    def create_product(_project_id, app_id, product)
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
      created_product_payloads << payload
      products << {
        'id' => "prod_#{app_id}_#{product.fetch('store_identifier')}",
        'store_identifier' => product.fetch('store_identifier'),
        'app_id' => app_id,
        'type' => product.fetch('type')
      }
      products.last
    end

    def list_offerings(_project_id)
      offerings
    end

    def create_offering(_project_id, offering)
      offerings << {
        'id' => "offering_#{offering.fetch('id')}",
        'lookup_key' => offering.fetch('id'),
        'display_name' => offering.fetch('display_name'),
        'is_current' => true
      }
      offerings.last
    end

    def update_offering(_project_id, offering_id, offering)
      offerings.find { |item| item.fetch('id') == offering_id }.merge!(
        'display_name' => offering.fetch('display_name'),
        'is_current' => offering.fetch('current', true)
      )
    end

    def list_packages(_project_id, _offering_id)
      packages
    end

    def create_package(_project_id, offering_id, package)
      packages << {
        'id' => "pkg_#{package.fetch('id')}",
        'offering_id' => offering_id,
        'lookup_key' => package.fetch('id'),
        'display_name' => package.fetch('display_name'),
        'position' => package.fetch('position')
      }
      packages.last
    end

    def update_package(_project_id, package_id, package)
      packages.find { |item| item.fetch('id') == package_id }.merge!(
        'display_name' => package.fetch('display_name'),
        'position' => package.fetch('position')
      )
    end

    def list_entitlement_products(_project_id, entitlement_id)
      @entitlement_products[entitlement_id]
    end

    def attach_products_to_entitlement(_project_id, entitlement_id, product_ids)
      product_ids.each do |product_id|
        product = products.find { |item| item.fetch('id') == product_id }
        @entitlement_products[entitlement_id] << product
      end
    end

    def list_package_products(_project_id, package_id)
      package_products[package_id]
    end

    def attach_products_to_package(_project_id, package_id, product_ids)
      product_ids.each do |product_id|
        product = products.find { |item| item.fetch('id') == product_id }
        package_products[package_id] << { 'product' => product, 'eligibility_criteria' => 'all' }
      end
    end
  end
end
