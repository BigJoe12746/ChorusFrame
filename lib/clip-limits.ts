// Clip-window limits, shared by the picker and the API.
//
// These lived only in the route, so the picker happily offered starts the
// server rejected: a 50MB upload cap is a BYTE cap, and a 192kbps MP3 hits it
// at roughly 36 minutes, so long tracks are routinely accepted. Anything past
// MAX_START was selectable and un-renderable.
export const MAX_START = 900; // 15:00
export const MIN_DURATION = 5;
export const MAX_DURATION = 60;
