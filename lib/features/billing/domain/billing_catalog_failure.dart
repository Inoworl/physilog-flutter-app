enum BillingCatalogFailure {
  invalidCredentials,
  configuration,
  noTestStoreProducts,
  offeringEmpty,
  productsUnavailable,
  invalidAppUserId,
  network,
  offline,
  endpointBlocked,
  unknown,
}

class BillingCatalogException implements Exception {
  const BillingCatalogException(this.failure);

  final BillingCatalogFailure failure;
}
