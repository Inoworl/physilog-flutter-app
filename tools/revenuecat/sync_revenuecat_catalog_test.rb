# frozen_string_literal: true

require 'minitest/autorun'
require 'tempfile'
require_relative 'sync_revenuecat_catalog'

class RevenueCatCatalogSyncTest < Minitest::Test
  def test_catalog_contains_prod_and_dev_projects
    catalog = RevenueCatCatalog::Catalog.load(File.expand_path('revenuecat_catalog.yaml', __dir__))

    assert_empty catalog.validate('dev')
    assert_empty catalog.validate('prod')
    assert_equal 'b9208054', catalog.environment('dev').fetch('project_id')
    assert_equal 'ec10fe6b', catalog.environment('prod').fetch('project_id')
  end

  def test_apply_to_prod_requires_app_id
    catalog = RevenueCatCatalog::Catalog.load(File.expand_path('revenuecat_catalog.yaml', __dir__))

    error = assert_raises(ArgumentError) do
      RevenueCatCatalog::Sync.new(catalog, 'prod', api: FakeRevenueCatApi.new).run(apply: true)
    end
    assert_equal 'Missing app_id for prod; product sync needs a RevenueCat app id', error.message
  end

  def test_default_api_key_env_name_is_based_on_target_environment
    assert_equal 'REVENUECAT_DEV_SECRET_API_KEY', RevenueCatCatalog.default_api_key_env('dev')
    assert_equal 'REVENUECAT_PROD_SECRET_API_KEY', RevenueCatCatalog.default_api_key_env('prod')
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

  def test_dry_run_plans_missing_catalog_items
    catalog = RevenueCatCatalog::Catalog.load(File.expand_path('revenuecat_catalog.yaml', __dir__))
    operations = RevenueCatCatalog::Sync.new(catalog, 'dev', api: FakeRevenueCatApi.new).run(apply: false)
    text = operations.map(&:to_s)

    assert_includes text, 'create entitlement personal_family Personal Family'
    assert_includes text, 'create product team_yearly intended JPY 8980'
    assert_includes text, 'create offering default Default'
    assert_includes text, 'create package personal_family_monthly position 1'
    assert_includes text, 'attach entitlement team team_monthly, team_yearly'
    assert_includes text, 'attach package team_yearly team_yearly'
  end

  def test_apply_creates_and_attaches_catalog_items
    api = FakeRevenueCatApi.new
    catalog = RevenueCatCatalog::Catalog.load(File.expand_path('revenuecat_catalog.yaml', __dir__))

    RevenueCatCatalog::Sync.new(catalog, 'dev', api: api).run(apply: true)

    assert_equal %w[personal_family team], api.entitlements.map { |item| item.fetch('lookup_key') }
    assert_equal %w[personal_family_monthly personal_family_yearly team_monthly team_yearly],
                 api.products.map { |item| item.fetch('store_identifier') }
    assert api.created_product_payloads.all? { |payload| payload.key?(:title) }
    assert api.created_product_payloads.all? { |payload| payload.fetch(:subscription).keys == [:duration] }
    assert_equal %w[personal_family_monthly personal_family_yearly team_monthly team_yearly],
                 api.package_products.values.flatten.map { |item| item.fetch('product').fetch('store_identifier') }
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
      created_product_payloads << {
        store_identifier: product.fetch('id'),
        app_id: app_id,
        type: product.fetch('type'),
        display_name: product.fetch('display_name'),
        title: product.fetch('title'),
        subscription: {
          duration: product.fetch('duration')
        }
      }
      products << {
        'id' => "prod_#{product.fetch('id')}",
        'store_identifier' => product.fetch('id'),
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
