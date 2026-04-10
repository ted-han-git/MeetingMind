# frozen_string_literal: true
# encoding: utf-8
#
# Rigorously validate the generated MeetingCrew.xcodeproj.
# Intended to run in CI or pre-commit to catch drift between disk and project.

require "xcodeproj"

p = Xcodeproj::Project.open("MeetingCrew.xcodeproj")

errors = []

# 1. Exactly one target
errors << "Target count != 1" unless p.targets.count == 1
target = p.targets.first

# 2. Required build settings on both configs
required_keys = %w[
  SDKROOT SUPPORTED_PLATFORMS
  IPHONEOS_DEPLOYMENT_TARGET MACOSX_DEPLOYMENT_TARGET
  INFOPLIST_FILE CODE_SIGN_ENTITLEMENTS
  PRODUCT_BUNDLE_IDENTIFIER SWIFT_VERSION
]
target.build_configurations.each do |c|
  required_keys.each do |k|
    errors << "#{c.name}: missing #{k}" unless c.build_settings[k]
  end
end

# 3. All Swift sources exist on disk
target.source_build_phase.files.each do |bf|
  path = bf.file_ref.real_path.to_s
  errors << "missing on disk: #{path}" unless File.exist?(path)
end

# 4. Disk vs target count
actual_swift  = Dir.glob("MeetingCrew/**/*.swift").count
tracked_swift = target.source_build_phase.files.count
unless actual_swift == tracked_swift
  errors << "Swift file count mismatch: disk=#{actual_swift} target=#{tracked_swift}"
end

# 5. Required resource files on disk
%w[
  MeetingCrew/Resources/Info.plist
  MeetingCrew/Resources/MeetingCrew.entitlements
  MeetingCrew/Resources/Assets.xcassets
].each do |f|
  errors << "Missing: #{f}" unless File.exist?(f)
end

# 6. Assets.xcassets in resources build phase
has_assets = target.resources_build_phase.files.any? { |bf| bf.file_ref.path == "Assets.xcassets" }
errors << "Assets.xcassets not in resources build phase" unless has_assets

# 7. Scheme UUID matches target UUID
scheme_path = "MeetingCrew.xcodeproj/xcshareddata/xcschemes/MeetingCrew.xcscheme"
scheme_content = File.read(scheme_path)
errors << "Scheme Blueprint UUID mismatch" unless scheme_content.include?(target.uuid)

# 8. No hardcoded iOS SDK paths
pbxproj_content = File.read("MeetingCrew.xcodeproj/project.pbxproj")
if pbxproj_content.include?("iPhoneOS18.0.sdk") || pbxproj_content.match?(/iPhoneOS\d+\.\d+\.sdk/)
  errors << "pbxproj contains hardcoded iOS SDK path"
end

# 9. objectVersion sane
unless pbxproj_content.match?(/objectVersion = (5[0-9]|6[0-9]);/)
  errors << "objectVersion not in 50..69 range"
end

# 10. Info.plist should NOT contain LSRequiresIPhoneOS (breaks macOS)
info_plist = File.read("MeetingCrew/Resources/Info.plist")
if info_plist.include?("LSRequiresIPhoneOS")
  errors << "Info.plist contains LSRequiresIPhoneOS (iOS-only, breaks macOS)"
end

puts "=" * 60
if errors.empty?
  puts "PASS - MeetingCrew.xcodeproj validation"
  puts "   Swift sources  : #{tracked_swift}"
  puts "   Resources      : #{target.resources_build_phase.files.count}"
  puts "   Configurations : #{target.build_configurations.map(&:name).join(', ')}"
  puts "   Target UUID    : #{target.uuid}"
  puts "=" * 60
  exit 0
else
  puts "FAIL - Validation errors:"
  errors.each { |e| puts "   - #{e}" }
  puts "=" * 60
  exit 1
end
