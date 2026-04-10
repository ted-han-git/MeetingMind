#!/usr/bin/env bash
#
# run-mac.sh — MeetingCrew를 macOS 앱으로 빌드하고 바로 띄웁니다.
# Xcode GUI를 열 필요 없이 터미널 한 줄로 끝납니다.
#
# 사용:
#   ./scripts/run-mac.sh              # 빌드 + 실행
#   ./scripts/run-mac.sh --clean      # DerivedData 삭제 후 처음부터 빌드
#   ./scripts/run-mac.sh --build-only # 빌드만 하고 실행은 안 함
#
# macOS에는 "시뮬레이터"가 없습니다. Mac 앱은 사용자님의 Mac 위에서
# 네이티브로 그대로 돌아갑니다 — 이 스크립트가 그 앱을 띄워줍니다.
#

set -euo pipefail

RED="\033[31m"; GRN="\033[32m"; YEL="\033[33m"; BLD="\033[1m"; RST="\033[0m"
log()  { printf "${BLD}==>${RST} %s\n" "$*"; }
ok()   { printf "${GRN}[OK]${RST} %s\n" "$*"; }
warn() { printf "${YEL}[WARN]${RST} %s\n" "$*"; }
die()  { printf "${RED}[ERROR]${RST} %s\n" "$*" >&2; exit 1; }

cd "$(dirname "$0")/.."

# ---------- 0. 인자 파싱 ----------
CLEAN=0
BUILD_ONLY=0
for arg in "$@"; do
  case "$arg" in
    --clean)      CLEAN=1 ;;
    --build-only) BUILD_ONLY=1 ;;
    -h|--help)
      sed -n '2,11p' "$0" | sed 's/^# //; s/^#//'
      exit 0
      ;;
    *) die "알 수 없는 옵션: $arg" ;;
  esac
done

# ---------- 1. 전제 조건 ----------
[ "$(uname)" = "Darwin" ] || die "이 스크립트는 macOS 전용입니다."
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild가 없습니다. Xcode를 먼저 설치해주세요."

PROJECT="MeetingCrew.xcodeproj"
SCHEME="MeetingCrew"
DERIVED="build/DerivedData"
BUNDLE_ID="com.meetingcrew.app"
APP_NAME="MeetingCrew"

[ -d "$PROJECT" ] || die "$PROJECT 가 없습니다. MeetingMind 저장소 루트에서 실행해주세요."

# ---------- 2. 이미 실행 중인 인스턴스 종료 ----------
if pgrep -x "$APP_NAME" >/dev/null 2>&1; then
  log "Quitting existing $APP_NAME instance..."
  osascript -e "tell application \"$APP_NAME\" to quit" 2>/dev/null || true
  # osascript가 안 먹으면 강제 종료
  sleep 1
  pkill -x "$APP_NAME" 2>/dev/null || true
  ok "Existing instance quit"
fi

# ---------- 3. (옵션) 클린 ----------
if [ "$CLEAN" -eq 1 ]; then
  log "Cleaning DerivedData..."
  rm -rf "$DERIVED"
  ok "Cleaned"
fi

# ---------- 4. 빌드 ----------
log "Building $APP_NAME for My Mac (ad-hoc signing)..."
# ad-hoc 서명("-")으로 빌드하면 개발팀 없이도 로컬 실행이 가능합니다.
# App Sandbox + 엔타이틀먼트는 유효한 서명(ad-hoc 포함)이 있어야 작동합니다.
BUILD_LOG="build/run-mac-last.log"
mkdir -p build

set +e
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
  build 2>&1 | tee "$BUILD_LOG" \
  | (command -v xcpretty >/dev/null 2>&1 && xcpretty || cat)

PIPE_RC=${PIPESTATUS[0]}
set -e

if [ "$PIPE_RC" -ne 0 ]; then
  echo
  die "빌드 실패 (xcodebuild exit $PIPE_RC). 전체 로그: $BUILD_LOG"
fi
ok "Build succeeded"

# ---------- 5. .app 번들 찾기 ----------
APP=$(find "$DERIVED/Build/Products" -type d -name "${APP_NAME}.app" -path "*Debug*" 2>/dev/null | head -1)
[ -n "$APP" ] || die "빌드 결과물(.app)을 찾지 못했습니다. 로그 확인: $BUILD_LOG"
ok "Built: $APP"

# ---------- 6. quarantine 플래그 제거 ----------
# ad-hoc 서명된 바이너리에 quarantine 속성이 붙어있으면 Gatekeeper가 막을 수 있음
if xattr -p com.apple.quarantine "$APP" >/dev/null 2>&1; then
  log "Removing quarantine flag..."
  xattr -cr "$APP" 2>/dev/null || true
  ok "Quarantine removed"
fi

if [ "$BUILD_ONLY" -eq 1 ]; then
  echo
  ok "--build-only 모드: 빌드만 완료. 실행은 생략."
  echo "   수동 실행: open \"$APP\""
  exit 0
fi

# ---------- 7. 실행 ----------
log "Launching $APP_NAME..."
# -n: 이미 떠 있어도 새 인스턴스 강제
# -a: 경로로 지정된 앱 실행 (Dock에 바로 올라감)
open -n "$APP"

# 창이 앞으로 오도록 activate
sleep 0.5
osascript -e "tell application \"$APP_NAME\" to activate" 2>/dev/null || true

ok "$APP_NAME 실행됨"

echo
echo "================================================================"
echo " 🎉 MeetingCrew Mac 앱이 실행됐어요!"
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
echo "  - 창이 안 보이면: Dock의 MeetingCrew 아이콘 클릭 / Cmd+Tab"
echo "  - 재빌드: ./scripts/run-mac.sh --clean"
echo "  - 빌드 로그 보기: cat $BUILD_LOG"
echo "  - 현재 .app 위치: $APP"
echo
