#!/usr/bin/env ruby
# frozen_string_literal: true

# Converts GoReleaser-generated `postflight` blocks (deprecated by Homebrew)
# into the equivalent declarative `postflight_steps` form.
#
# Idempotent. Exits non-zero if any cask still contains `postflight do`
# afterwards, e.g. because GoReleaser changed the shape of its output.
#
# Remove once all casks are released with GoReleaser >= v2.19 using
# `hooks.post.install_steps`. See goreleaser/goreleaser#6870.

LEGACY_BLOCK = /
  ^(?<indent>[ ]*)postflight\ do\n
  [ ]*if\ OS\.mac\?\n
  [ ]*system_command\ "\/usr\/bin\/xattr",\ args:\ \["-dr",\ "com\.apple\.quarantine",\ "\#\{staged_path\}\/(?<name>[^"]+)"\]\n
  [ ]*end\n
  [ ]*end\n
/x

casks_dir = File.expand_path("../Casks", __dir__)
changed = []
unconverted = []

Dir.glob(File.join(casks_dir, "*.rb")).sort.each do |path|
  original = File.read(path)
  updated = original.gsub(LEGACY_BLOCK) do
    m = Regexp.last_match
    i = m[:indent]
    <<~RUBY.gsub(/^/, i)
      postflight_steps do
        on_macos do
          run "/usr/bin/xattr", args: ["-dr", "com.apple.quarantine", "{{staged_path}}/#{m[:name]}"]
        end
      end
    RUBY
  end

  if updated != original
    File.write(path, updated)
    changed << path
  end
  unconverted << path if updated.match?(/^\s*postflight do\b/)
end

changed.each { |path| puts "Converted #{File.basename(path)}" }
puts "No casks needed converting" if changed.empty?

unless unconverted.empty?
  warn "Unrecognised `postflight` block remains in:"
  unconverted.each { |path| warn "  #{File.basename(path)}" }
  exit 1
end
