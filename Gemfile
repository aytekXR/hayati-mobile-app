# Gemfile — Ruby dependencies for fastlane (repo root).
#
# fastlane is pinned to the current 2.x major. It is NOT exercised in CI yet:
# the M0.2 pipeline builds iOS via the Flutter toolchain directly (ci.yml), and
# fastlane first runs for real in M6 (TestFlight / release.yml).
#
# Gemfile.lock is intentionally absent (documented debt — see fastlane/README.md):
# there is no Ruby/bundler on the dev machine yet, so we cannot generate a
# faithful lock. It gets committed the first time fastlane is exercised in M6.

source "https://rubygems.org"

gem "fastlane", "~> 2.225"
