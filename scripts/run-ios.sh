#!/usr/bin/env bash
#
# run-ios.sh — MeetingCrew를 iOS Simulator에 설치하고 바로 띄웁니다.
# Xcode GUI를 열 필요 없이 터미널 한 줄로 끝납니다.
#
# 사용:
#   ./scripts/run-ios.sh                       # 기본 시뮬레이터 자동 선택
#   ./scripts/run-ios.sh "iPhone 16"           # 특정 기기 지정
#

set -euo pipefail

RED="\033[31m"; GRN="\033[32m"; YEL="\033[33m"; BLD="\033[1m"; RST="\033[0m"
log()  { printf "${BLD}==>${RST} %s\n" "$*"; }
ok()   { printf "${GRN}[OK]${RST} %s\n" "$*"; }
warn() { printf "${YEL}[WARN]${RST} %s\n" "$*"; }
die()  { printf "${RED}[ERROR]${RST} %s\n" "$*" >&2; exit 1; }

cd "$(dirname "$0")/.."

[ "$(uname)" = "Darwin" ] || die "이 스크립트는 macOS 전용입니다."
command -v xcodebuild >/dev/null 2>&1 || die "xcodebuild가 없습니다."
command -v xcrun >/dev/null 2>&1 || die "xcrun이 없습니다."

PROJECT="MeetingCrew.xcodeproj"
SCHEME="MeetingCrew"
DERIVED="build/DerivedData"
BUNDLE_ID="com.meetingcrew.app"
REQUESTED_DEVICE="${1:-}"

# ---------- 1. 시뮬레이터 선택 ----------
log "Selecting iOS Simulator..."

# 사용 가능한 iPhone 시뮬레이터 목록을 JSON으로 가져와 첫 번째 최신 것을 고름
DEVICE_INFO=$(xcrun simctl list devices available --json 2>/dev/null)

pick_device() {
  python3 - "$DEVICE_INFO" "$REQUESTED_DEVICE" <<'PY'
import json, sys
data = json.loads(sys.argv[1])
requested = sys.argv[2].strip()

candidates = []
for runtime, devices in data.get("devices", {}).items():
    if "iOS" not in runtime:
        continue
    for d in devices:
        if d.get("isAvailable", False) and "iPhone" in d.get("name", ""):
            candidates.append((runtime, d["name"], d["udid"]))

if not candidates:
    sys.exit(1)

# 특정 기기 요청이 있으면 그것 우선
if requested:
    for r, n, u in candidates:
        if n == requested:
            print(u); print(n)
            sys.exit(0)

# 아니면 iPhone 16/15/14 순으로 선호
for pref in ("iPhone 16 Pro", "iPhone 16", "iPhone 15 Pro", "iPhone 15", "iPhone 14"):
    for r, n, u in candidates:
        if n == pref:
            print(u); print(n)
            sys.exit(0)

# 그래도 없으면 첫 번째 것
r, n, u = candidates[0]
print(u); print(n)
PY
}

if ! DEVICE_OUT=$(pick_device); then
  die "사용 가능한 iPhone 시뮬레이터가 없습니다. Xcode → Settings → Platforms 에서 iOS 런타임을 설치해주세요."
fi

DEVICE_UDID=$(printf "%s\n" "$DEVICE_OUT" | sed -n '1p')
DEVICE_NAME=$(printf "%s\n" "$DEVICE_OUT" | sed -n '2p')
ok "Device: $DEVICE_NAME ($DEVICE_UDID)"

# ---------- 2. 시뮬레이터 부팅 ----------
log "Booting simulator..."
BOOT_STATE=$(xcrun simctl list devices | grep "$DEVICE_UDID" | grep -oE "\(Booted\)|\(Shutdown\)" || echo "")
if [ "$BOOT_STATE" != "(Booted)" ]; then
  xcrun simctl boot "$DEVICE_UDID"
fi
open -a Simulator
ok "Simulator app opened"

# ---------- 3. 빌드 ----------
log "Building MeetingCrew for iOS Simulator..."
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Debug \
  -destination "id=$DEVICE_UDID" \
  -derivedDataPath "$DERIVED" \
  CODE_SIGNING_ALLOWED=NO \
  build \
  | (command -v xcpretty >/dev/null 2>&1 && xcpretty || cat)

PIPE_RC=${PIPESTATUS[0]}
[ "$PIPE_RC" -eq 0 ] || die "빌드 실패 (xcodebuild exit $PIPE_RC)"

APP=$(find "$DERIVED/Build/Products" -type d -name "MeetingCrew.app" -path "*iphonesimulator*" 2>/dev/null | head -1)
[ -n "$APP" ] || die "빌드 결과물(.app)을 찾지 못했습니다."
ok "Built: $APP"

# ---------- 4. 설치 + 실행 ----------
log "Installing on $DEVICE_NAME..."
xcrun simctl install "$DEVICE_UDID" "$APP"
ok "Installed"

log "Launching $BUNDLE_ID..."
xcrun simctl launch "$DEVICE_UDID" "$BUNDLE_ID"
ok "Launched"

echo
echo "================================================================"
echo " 🎉 Simulator에서 앱이 실행됐어요!"
echo "================================================================"
echo
echo "Simulator 창에서:"
echo "  1. 상단 ⚙️  톱니바퀴 아이콘 탭"
echo "  2. Claude API Key 붙여넣기 (Mac에서 복사한 키를 Cmd+V)"
echo "  3. [연결 테스트] → 초록 메시지 확인"
echo "  4. [저장]"
echo "  5. [녹음 시작] → 권한 [승인] → 한국어로 말해보기"
echo
echo "⚠️  참고: iOS Simulator에서 마이크 입력은 Mac의 마이크를 그대로 씁니다."
echo
