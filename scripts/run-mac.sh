#!/usr/bin/env bash
#
# run-mac.sh — MeetingCrew를 macOS 앱으로 빌드하고 바로 띄웁니다.
# Xcode GUI를 열 필요 없이 터미널 한 줄로 끝납니다.
#
# 사용:
#   ./scripts/run-mac.sh
#

set -euo pipefail

RED="\033[31m"; GRN="\033[32m"; YEL="\033[33m"; BLD="\033[1m"; RST="\033[0m"
log()  { printf "${BLD}==>${RST} %s\n" "$*"; }
ok()   { printf "${GRN}[OK]${RST} %s\n" "$*"; }
die()  { printf "${RED}[ERROR]${RST} %s\n" "$*" >&2; exit 1; }

cd "$(dirname "$0")/.."

[ "$(uname)" = "Darwin" ] || die "이 스크립트는 macOS 전용입니다."
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild가 없습니다. Xcode를 먼저 설치해주세요."

PROJECT="MeetingCrew.xcodeproj"
SCHEME="MeetingCrew"
DERIVED="build/DerivedData"

log "Building MeetingCrew for My Mac..."
# ad-hoc 서명("-")으로 빌드하면 개발팀 없이도 로컬 실행이 가능합니다.
# App Sandbox + 엔타이틀먼트는 유효한 서명(ad-hoc 포함)이 있어야 작동합니다.
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "generic/platform=macOS" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  build \
  | (command -v xcpretty >/dev/null 2>&1 && xcpretty || cat)

PIPE_RC=${PIPESTATUS[0]}
[ "$PIPE_RC" -eq 0 ] || die "빌드 실패 (xcodebuild exit $PIPE_RC)"

# 생성된 .app 경로 찾기
APP=$(find "$DERIVED/Build/Products" -type d -name "MeetingCrew.app" -path "*Debug*" 2>/dev/null | head -1)
[ -n "$APP" ] || die "빌드 결과물(.app)을 찾지 못했습니다."

ok "Built: $APP"

log "Launching MeetingCrew..."
open "$APP"
ok "앱이 실행되었습니다. Dock에서 MeetingCrew 아이콘을 확인하세요."

echo
echo "================================================================"
echo " 🎉 앱이 실행됐어요!"
echo "================================================================"
echo
echo "앱 창이 뜨면:"
echo "  1. 오른쪽 상단 ⚙️  아이콘 클릭"
echo "  2. Claude API Key 붙여넣기 (sk-ant-api03-...)"
echo "  3. [연결 테스트] → 초록 메시지 확인"
echo "  4. [저장]"
echo "  5. [녹음 시작] → 마이크/음성인식 권한 [승인] → 한국어로 말해보기"
echo
echo "문제가 있으면:"
echo "  - Dock에 MeetingCrew가 안 보이면: open \"$APP\" 다시 실행"
echo "  - 빌드 에러: ./scripts/setup-mac.sh 먼저 실행해서 전체 점검"
echo
