#!/usr/bin/env ruby
# frozen_string_literal: true
#
# MeetingCrew.xcodeproj를 생성한다.
# 하나의 멀티플랫폼 SwiftUI 타겟 (iOS 17+ / macOS 14+).
#
# 사용: ruby scripts/generate_xcodeproj.rb

require 'xcodeproj'
require 'fileutils'

ROOT = File.expand_path('..', __dir__)
Dir.chdir(ROOT)

PROJECT_PATH = 'MeetingCrew.xcodeproj'
FileUtils.rm_rf(PROJECT_PATH)

project = Xcodeproj::Project.new(PROJECT_PATH)
project.root_object.attributes['LastSwiftUpdateCheck'] = '1500'
project.root_object.attributes['LastUpgradeCheck'] = '1500'
project.root_object.attributes['ORGANIZATIONNAME'] = 'MeetingCrew'

# --- 타겟 생성 (iOS 기준으로 만들고 macOS도 지원하도록 build settings 오버라이드) ---
target = project.new_target(
  :application,
  'MeetingCrew',
  :ios,
  '17.0',
  nil,
  :swift
)

# xcodeproj gem이 기본 추가한 Foundation.framework 레퍼런스는 iOS SDK 경로가
# 하드코딩되어 있어 macOS 빌드와 Xcode 버전 호환성을 해친다.
# SwiftUI/Speech 등 모든 프레임워크는 Swift가 자동 링크하므로 제거한다.
if target.frameworks_build_phase
  target.frameworks_build_phase.files.to_a.each do |bf|
    bf.remove_from_project
  end
end
# Frameworks 그룹의 파일 레퍼런스도 정리
if (fw_group = project.main_group['Frameworks'])
  fw_group.clear
end

# --- 그룹/파일 레퍼런스 ---
main_group = project.main_group
main_group.set_source_tree('<group>')

app_group = main_group.new_group('MeetingCrew', 'MeetingCrew')
app_group.set_source_tree('<group>')

def add_swift_sources(project, target, parent_group, folder)
  group = parent_group.new_group(folder, folder)
  group.set_source_tree('<group>')
  Dir.glob(File.join("MeetingCrew", folder, "*.swift")).sort.each do |path|
    file_name = File.basename(path)
    ref = group.new_reference(file_name)
    ref.last_known_file_type = 'sourcecode.swift'
    target.add_file_references([ref])
  end
end

%w[App Agents Views Services Models].each do |sub|
  add_swift_sources(project, target, app_group, sub)
end

# --- Resources (Assets, Info.plist, entitlements) ---
resources_group = app_group.new_group('Resources', 'Resources')
resources_group.set_source_tree('<group>')

assets_ref = resources_group.new_reference('Assets.xcassets')
assets_ref.last_known_file_type = 'folder.assetcatalog'
target.resources_build_phase.add_file_reference(assets_ref)

info_ref = resources_group.new_reference('Info.plist')
info_ref.last_known_file_type = 'text.plist.xml'

entitlements_ref = resources_group.new_reference('MeetingCrew.entitlements')
entitlements_ref.last_known_file_type = 'text.plist.entitlements'

# --- Build settings ---
common = {
  'SWIFT_VERSION'                                  => '5.9',
  'PRODUCT_BUNDLE_IDENTIFIER'                      => 'com.meetingcrew.app',
  'PRODUCT_NAME'                                   => '$(TARGET_NAME)',
  'MARKETING_VERSION'                              => '1.0.0',
  'CURRENT_PROJECT_VERSION'                        => '1',
  'GENERATE_INFOPLIST_FILE'                        => 'NO',
  'INFOPLIST_FILE'                                 => 'MeetingCrew/Resources/Info.plist',
  'INFOPLIST_KEY_CFBundleDisplayName'              => 'MeetingCrew',
  'INFOPLIST_KEY_LSApplicationCategoryType'        => 'public.app-category.productivity',
  'INFOPLIST_KEY_NSHumanReadableCopyright'         => '',
  'CODE_SIGN_ENTITLEMENTS'                         => 'MeetingCrew/Resources/MeetingCrew.entitlements',
  'CODE_SIGN_IDENTITY'                             => '-',
  'CODE_SIGN_STYLE'                                => 'Manual',
  'DEVELOPMENT_TEAM'                               => '',
  'IPHONEOS_DEPLOYMENT_TARGET'                     => '17.0',
  'MACOSX_DEPLOYMENT_TARGET'                       => '14.0',
  'SDKROOT'                                        => 'auto',
  'SUPPORTED_PLATFORMS'                            => 'iphoneos iphonesimulator macosx',
  'SUPPORTS_MACCATALYST'                           => 'NO',
  'SUPPORTS_MAC_DESIGNED_FOR_IPHONE_IPAD'          => 'NO',
  'TARGETED_DEVICE_FAMILY'                         => '1,2',
  'ASSETCATALOG_COMPILER_APPICON_NAME'             => 'AppIcon',
  'ASSETCATALOG_COMPILER_GLOBAL_ACCENT_COLOR_NAME' => 'AccentColor',
  'ENABLE_HARDENED_RUNTIME'                        => 'NO',
  'ENABLE_PREVIEWS'                                => 'YES',
  'LD_RUNPATH_SEARCH_PATHS'                        => [
    '$(inherited)',
    '@executable_path/Frameworks',
    '@executable_path/../Frameworks'
  ],
  'SWIFT_EMIT_LOC_STRINGS'                         => 'YES',
  'CLANG_ENABLE_MODULES'                           => 'YES',
  'ENABLE_USER_SCRIPT_SANDBOXING'                  => 'NO'
}

target.build_configurations.each do |config|
  config.build_settings.merge!(common)
  if config.name == 'Debug'
    config.build_settings['SWIFT_ACTIVE_COMPILATION_CONDITIONS'] = 'DEBUG'
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-Onone'
  else
    config.build_settings['SWIFT_OPTIMIZATION_LEVEL'] = '-O'
    config.build_settings['SWIFT_COMPILATION_MODE'] = 'wholemodule'
  end
end

# 프로젝트 수준 빌드 설정 (일부 기본값 정리)
project.build_configurations.each do |config|
  config.build_settings['IPHONEOS_DEPLOYMENT_TARGET'] = '17.0'
  config.build_settings['MACOSX_DEPLOYMENT_TARGET']   = '14.0'
  config.build_settings['SWIFT_VERSION']              = '5.9'
  config.build_settings['ALWAYS_SEARCH_USER_PATHS']   = 'NO'
  config.build_settings['CLANG_ANALYZER_NONNULL']     = 'YES'
  config.build_settings['ENABLE_STRICT_OBJC_MSGSEND'] = 'YES'
end

project.save

# --- objectVersion을 Xcode 15+ 수준으로 올림 ---
pbxproj_path = File.join(PROJECT_PATH, 'project.pbxproj')
content = File.read(pbxproj_path)
content.sub!(/objectVersion = \d+;/, 'objectVersion = 56;')
File.write(pbxproj_path, content)

# --- Shared scheme ---
scheme = Xcodeproj::XCScheme.new
scheme.add_build_target(target)
scheme.add_test_target(target) rescue nil
scheme.set_launch_target(target)
scheme.save_as(PROJECT_PATH, 'MeetingCrew', true)

puts "✅ Generated #{PROJECT_PATH}"
