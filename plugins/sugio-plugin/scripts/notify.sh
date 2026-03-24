#!/usr/bin/env bash
# 通知を表示し、数秒後に通知センターから自動消去する
# Usage: ./notify.sh [message] [title]

MESSAGE="${1:-Claude Code needs your attention}"
TITLE="${2:-Claude Code}"

# 通知を表示
osascript -e "display notification \"$MESSAGE\" with title \"$TITLE\""

# バックグラウンドで通知センターの該当通知を閉じる
(sleep 4 && osascript << 'OSASCRIPT'
tell application "System Events"
    tell process "NotificationCenter"
        try
            repeat with w in (get every window)
                try
                    click button "Close" of w
                end try
            end repeat
        end try
    end tell
end tell
OSASCRIPT
) &
