# ADR-073: The `.p8` step is PROVEN inert to fastlane, still unproven against xcodebuild — so ADR-056 D4 stands, with citations instead of reasoning

- **Status:** Accepted — **ADR-056 D4's decision is unchanged.** What changes is the evidence under it: an asserted premise is now a cited one, and the open question is narrowed from two unknowns to one.
- **Date:** 2026-09-03 (Session 099)
- **Deciders:** session agent. **Nothing is deleted and nothing is dispatched.** The one remaining experiment needs a release run — operator **6(c)**.
- **Related:** **ADR-056 D4** (which declined to delete this step and designed the experiment that settles it — unamended here), **ADR-032 D4** (which kept the step and stated the reasoning this ADR cites), **ADR-029 D2** (the no-blind-edits precedent both rest on), **ADR-021 D5** (the cloud signing the step was written for), issue **#121**, lessons **78**, **81**, **135**, **145**, **153**

## Context

`release.yml`'s `write App Store Connect API key` step decodes
`ASC_API_KEY_P8_BASE64` onto xcodebuild's auto-discovery path,
`$HOME/.appstoreconnect/private_keys/AuthKey_${ASC_KEY_ID}.p8`. It exists for
**ADR-021 D5's cloud signing**, which **ADR-032** replaced with fastlane `match`
and manual signing. Three documents say nothing reads it any more and all three
say it as **reasoning**, not as a citation:

> Under manual signing, xcodebuild's `~/.appstoreconnect/private_keys`
> auto-discovery path is consulted only by `-allowProvisioningUpdates`, and
> fastlane receives the key through `app_store_connect_api_key(key_content:)`
> instead — so the step looks inert *(ADR-032 D4)*

⚠️ **This session was handed #121 as an open question, and its own resume prompt
was wrong about that** — the corollary of lesson **145**, landing on the prompt
the previous session wrote. **ADR-056 D4 had already decided it**: the step is not
deleted, on ADR-029 D2's grounds, and D4 went further and *designed the
experiment* — redirect the destination to a path nothing can auto-discover, run
the lane, and read the outcome; a failure is then attributable rather than
cryptic, which deleting the step outright would throw away.

What the prompt *did* get right is its bound (acceptance 4): **reading the vendor
source can prove "nothing in fastlane reads that path"; it cannot prove
"xcodebuild never does", because xcodebuild is not in the gem.** That bound is
exactly what happened.

### How it was measured, without installing Ruby

`ruby` and `bundle` are absent from this box and `ruby-full` needs `sudo`, which
is not available non-interactively. **None of that was needed: a `.gem` is a tar
archive, and reading Ruby does not require running it.**

```sh
curl -sSL -o fastlane.gem https://rubygems.org/downloads/fastlane-2.237.0.gem
tar xf fastlane.gem && tar xzf data.tar.gz -C src
```

**2.237.0 is the version `Gemfile.lock` pins**, so this is the code the release
lane actually loads — not the latest, and not the documentation. *Only the vendor
can refute a vendor API shape*, and the gem **is** the vendor.

## Decision 1 — The fastlane half is CLOSED, by citation

Three facts, each with its file and its line, from fastlane **2.237.0**:

| claim | evidence |
|---|---|
| fastlane never reads a pre-existing key file in this lane | `fastlane/lib/fastlane/actions/app_store_connect_api_key.rb`, in `Actions#run`: `key: key_content \|\| File.binread(File.expand_path(key_filepath))`. **`key_content` is what the Fastfile passes** — all three lanes do, `key_content: ENV.fetch("ASC_API_KEY_P8_BASE64")` — so the `File.binread` branch is **unreachable** |
| when fastlane needs a `.p8` on disk it **writes its own** | `fastlane_core/lib/fastlane_core/itunes_transporter.rb`, `TransporterExecutor#prepare`: `File.open(File.join(api_key[:key_dir], "AuthKey_#{api_key[:key_id]}.p8"), "wb")` — created from the key it already holds, and `"wb"` overwrites unconditionally |
| on **this** runner that directory is a temp dir, not the home path | same method: the home path is used **only** `if self.kind_of?(ShellScriptTransporterExecutor)`; every other executor gets `Dir.mktmpdir("deliver-")`. `ItunesTransporter#initialize` sets `use_shell_script` only for Xcode 6, Windows, or the `FASTLANE_ITUNES_TRANSPORTER_USE_SHELL_SCRIPT` feature flag, and `should_use_altool?` requires `Helper.xcode_at_least?(14)`. **`sign-upload` runs on `macos-26`** — so the executor is Altool or Java, never ShellScript |

**Conclusion: nothing in fastlane 2.237.0 reads, writes, or looks at
`~/.appstoreconnect/private_keys` on this lane's runner.** ADR-032 D4's sentence
was right about fastlane and is now citable rather than plausible.

### 1.1 — A hazard this ADR nearly reported, and did not

The first read of `prepare` found `FileUtils.rm_rf(api_key[:key_dir])` in the
`ensure` of `ItunesTransporter#upload` and `#provider_ids`, with `key_dir` set to
`~/.appstoreconnect/private_keys` — i.e. **fastlane recursively deleting a
developer's App Store Connect key directory after every upload.** That was about
to be written down as a live hazard.

**It is not one here.** The home path is reached only by
`ShellScriptTransporterExecutor`, which this runner never selects (above), so the
`rm_rf` targets the temp dir. It is recorded as a **conditional** caveat — real on
an Xcode-6, Windows, or feature-flagged machine — and not as a finding about this
lane. Lesson **135**: the load-bearing claim gets measured, *including* one you
have just produced yourself and like the look of.

## Decision 2 — The step STAYS. ADR-056 D4 is not amended, because its premise did not change

D4 declined deletion on one ground: *"A session that can watch a real run should
delete it and confirm"*, and no session can. **That is still true**, and D1 does
not touch it — `xcodebuild` is not in the gem, and
`flutter build ipa --export-options-plist` runs **before** the upload, so the
step's file *is* present during the only phase that could consult it.

So the state of #121 is now exactly one unknown instead of two:

| half | status |
|---|---|
| does **fastlane** read it? | **NO — proven**, D1 |
| does **xcodebuild** read it under manual signing with an explicit `ExportOptions.plist`? | **unknown, and unknowable from here** |

⚠️ **Naming which instrument proved which half** (lesson **78**), because the
temptation is to report the first row as the answer: the gem proves a statement
about *fastlane* and says nothing whatever about Apple's toolchain. A summary of
this ADR that reads *"the step is proven dead"* would be false, and it is the
false version that gets remembered.

**What would settle it is already designed** — ADR-056 D4's redirect, not a
deletion. This ADR adds one observation D4 could not have: **the timing objection
it recorded has inverted.** D4 declined *"for timing rather than principle: a
failed release costs more than usual right now, because a build is the single
thing blocking push-notification testing"*. A build is no longer that: production
has been down since 2026-08-22, and `operator-expected.md` item 4 now says
explicitly to cut a build **after** billing, because the registration call is
refused until then. **A failed release costs less today than when the experiment
was declined**, and that is the founder's to weigh — it is put to them as part of
operator **6(c)** rather than decided here.

## Decision 3 — The evidence goes where the claim is, and nowhere else

The corrected, cited reasoning is written into **the step's own comment in
`release.yml`** — the one place that speaks in the present tense about what the
step does — and into **#121**, so the next session inherits citations instead of
re-deriving them.

**ADR-032 D4 and ADR-056 D4 are left exactly as written.** They are records of
what was decided then, on the evidence then, and both decided correctly; editing
an accepted ADR to look better informed than it was is how a decision log stops
being one. This record supersedes neither.

## Consequences

**Positive**

- #121 goes from *"two things are unproven"* to *"one is proven and one needs a
  run"*, with file-and-line evidence at the pinned version.
- A near-miss hazard is recorded as conditional rather than shipped as a finding.
- **Ruby was not installed and did not need to be.** The resume prompt made it
  step one of the objective; reading a gem needs `tar`, not `ruby`. Recorded so a
  future session does not spend a `sudo` prompt on it — and `ruby-full` *would*
  need one, which would have made an operator dependency out of nothing.

**Negative / accepted trade-offs**

- **The step is still there, and still probably useless.** This ADR buys evidence,
  not deletion. The cost of being wrong is unchanged: a broken release the founder
  cannot debug.
- **The proof is version-pinned.** It holds for fastlane 2.237.0. A `Gemfile.lock`
  bump re-opens it, and the citation says which version it was taken from so that
  is visible rather than silent.
- The experiment that closes #121 remains gated on a founder decision. #121 stays
  **open**, which is the honest state and not a failure of this session.
