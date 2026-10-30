/// Physical storage isolation for an explicitly built web feature preview.
/// Empty by default: existing native/tablet installations keep every old key.
/// This is not a data migration and does not change serialized artwork references.
const tableStorageNamespace = String.fromEnvironment('TABLE_STORAGE_NAMESPACE');
const _prefix = tableStorageNamespace == '' ? '' : '${tableStorageNamespace}__';

abstract final class TableStorageKeys {
  static const aggregate = '${_prefix}tripling_season_tablet_aggregate_v1';
  static const catalog = '${_prefix}tripling_season_tablet_catalog_v1';
  static const media = '${_prefix}tripling_table_media_v1';
  static const supportOwned = '${_prefix}tablet_support_owned_v1';
  static const supportColor = '${_prefix}tablet_support_heart_color';
}
