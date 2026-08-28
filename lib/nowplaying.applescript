tell application "Spotify"
	set playerStateText to (player state as text)
	if playerStateText is "stopped" then return "stopped||||"
	set trackName to (name of current track)
	set artistName to (artist of current track)
	set posSec to ((player position) as integer)
	set durSec to (((duration of current track) / 1000) as integer)
	return playerStateText & "|" & trackName & "|" & artistName & "|" & posSec & "|" & durSec
end tell
