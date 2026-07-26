# Gemfile — Ruby dependencies for fastlane (repo root).
#
# fastlane is pinned to the current 2.x major. It is NOT exercised in CI yet:
# the M0.2 pipeline builds iOS via the Flutter toolchain directly (ci.yml), and
# fastlane first runs for real in M6 (TestFlight / release.yml).
#
# fastlane IS exercised in CI now (release.yml's sign-upload; the lane has built,
# signed and uploaded real TestFlight builds). ADR-021 D6 tied the Gemfile.lock debt
# to exactly that event, so the debt came due — see issue #120.
#
# The original blocker still stands: there is no Ruby/bundler on the Linux dev box,
# so no faithful lock can be generated there, and hand-authoring one from a CI log
# would look authoritative while being a guess. So CI generates it:
# `.github/workflows/gemfile-lock.yml` (workflow_dispatch) resolves the graph on the
# SAME runner + Ruby the release lane installs on, proves it with
# `bundle install --frozen` — the `npm ci` of this ecosystem, per the S044 lesson —
# and hands the file back as an artifact for a human to commit.

source "https://rubygems.org"

gem "fastlane", "~> 2.225"
