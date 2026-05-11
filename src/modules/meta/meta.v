// Module meta exposes project identity (name + semver) as compile-time
// constants so the CLI banner and the `<meta name="generator">` tag
// cannot drift apart.
module meta

pub const name = 'Verne'
pub const version = '0.2.0'
