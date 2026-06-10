// UTM-style keys captured from install referrers and deep links. These mirror
// the OneViw web/React Native SDKs so a team running multiple platforms against
// the same project gets unified property names.

/// Default UTM keys captured from referrer strings and deep links.
///
/// Deliberately conservative — click IDs ([clickIdKeys]) carry per-user
/// identifiers and are off by default. Pass a custom `campaignKeys` list in
/// [OneViwConfig] to opt into additional keys.
const List<String> defaultCampaignKeys = <String>[
  'utm_source',
  'utm_medium',
  'utm_campaign',
  'utm_content',
  'utm_term',
];

/// Click-ID keys provided for convenience. Not captured unless opted into via
/// `campaignKeys`, since these are typically PII-adjacent.
///
/// ```dart
/// OneViwConfig('<token>')
///   ..campaignKeys = [...defaultCampaignKeys, ...clickIdKeys];
/// ```
const List<String> clickIdKeys = <String>[
  'gclid',
  'gad_source',
  'gclsrc',
  'dclid',
  'gbraid',
  'wbraid',
  'fbclid',
  'msclkid',
  'twclid',
  'li_fat_id',
  'mc_cid',
  'igshid',
  'ScCid',
  'ttclid',
  'rdt_cid',
];
