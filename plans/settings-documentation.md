# Departure Board — Settings Reference

A detailed guide to every setting in the app, including the nuances of auto-loading and the favourites export format.

---

## Nearby Stations

**Setting:** Show N stations (1–25, default 5)

Controls how many nearby stations appear in the **Nearby** section at the top of the station list when location permission has been granted.

The list is sorted by straight-line distance from your current location and updates whenever your position changes significantly. It is unrelated to favourites — it shows any station, whether favourited or not.

**Practical guidance:**
- If you live or work near a single station, keep this at 1–3 to avoid clutter.
- If you're a frequent traveller who passes through multiple interchanges, increase to 10–15 so you don't have to search.
- The section disappears entirely if location permission is denied.

---

## Favourites

### Show Next Service

When enabled, each favourite card on the home screen shows the next scheduled departure time for that board — e.g. "in 4 min" or "14:32". The time is fetched in the background and refreshes automatically every 60 seconds.

This is a live departure query for each favourite, so with many favourites it makes proportionally more API calls on launch and during background refresh. Disabling it gives a snappier home screen if you have 10+ favourites.

### Tap to Jump to Service (requires Show Next Service)

When enabled, tapping the next departure time pill on a favourite card opens the full **Service Detail** view for that specific train — calling points, live delay status, platform assignment, and formation.

When disabled, tapping anywhere on a favourite card (including the time pill) opens the full **departure board** for that station instead.

**Nuance:** The tap target is specifically the time pill, not the whole row. The row itself always navigates to the board regardless of this setting.

### Split-Flap Refresh (requires Show Next Service)

When enabled, departure times on favourite cards animate with a split-flap (Solari board) effect each time new live data arrives. Each character cycles through the alphabet/digits before landing on the new value.

The animation is purely cosmetic. It has no effect on the underlying data or refresh rate. Turn it off if you find the motion distracting, or if you're testing and want instant updates.

---

## Auto-Load on Launch

This is the most complex setting in the app. It controls what happens the moment the app opens.

### Modes

| Mode | Behaviour |
|------|-----------|
| **Disabled** | App opens on the station list. Nothing loads automatically. |
| **Nearest Station** | The nearest station's departure board opens immediately, regardless of whether it's a favourite. |
| **Nearby Favourite** | If any favourite board belongs to a station within the configured distance, that board opens. Otherwise, the station list is shown. |
| **Favourite, then Nearest** | Checks for a favourite within range first. If found, opens it. If not, falls back to the nearest station (same as "Nearest Station" mode). |

### Distance Threshold (Nearby Favourite and Favourite, then Nearest only)

A stepper lets you set the radius in miles (1–50 mi, default 2 mi) within which a favourite must lie for auto-loading to trigger.

- **2 mi** is a sensible default for most home and work locations — close enough that you're genuinely near your usual station, far enough that a slight GPS drift doesn't prevent loading.
- **Increase** if you're in a rural area where stations are spaced further apart and you want the feature to trigger from home even if your GPS puts you a few miles away.
- **Decrease** if you live equidistant between two stations you use for different routes and want to ensure only the correct one fires.

### Priority When Multiple Favourites Are in Range

When **Nearby Favourite** or **Favourite, then Nearest** is active and more than one favourite station falls within the configured distance, **the app loads the favourite that is highest in your favourites list** — not the geographically closest one.

This is a deliberate design choice: you explicitly control priority by reordering your favourites. Drag your most important board to the top of the favourites list to ensure it takes priority.

**Example:** You live between Leeds and Bradford. Both are within 2 miles. Leeds Departures is higher in your list → Leeds Departures opens.

### Location Permission

Auto-load modes that require location (all except Disabled) only trigger if the app has been granted location access. If permission is denied, the app falls back to showing the station list regardless of this setting.

The app requests "When in Use" location permission — it does not request background location. Auto-loading only fires on foreground launch.

---

## Appearance

### Station Names in Small Caps

Renders station names in [lowercase small capitals](https://en.wikipedia.org/wiki/Small caps) throughout the app — boards, service detail, and station info. This is a typographic preference only; it has no functional effect.

Small caps can make long station names slightly more compact and are easier for some people to scan quickly on dense lists. Others find the default mixed case more legible. Try it and decide.

---

## Recent Filters

When you filter a departure or arrival board to show only trains to or from a specific station, that filter combination is saved and appears in the **Recent Filters** section on the home screen, so you can re-apply it with a single tap next time.

### Show Recent Filters

Hides or shows the Recent Filters section entirely. Disabling this doesn't delete your saved filters — they're still stored and will reappear if you re-enable the setting.

### Keep N Recent (1–10, default 3)

How many past filter combinations are remembered. When the list is full, the oldest entry is dropped to make room for new ones. Increase this if you have many regular routes; lower it for a tidier home screen.

---

## Maps

Controls which maps app opens when you tap the map in a **Station Information** sheet.

| Option | Behaviour |
|--------|-----------|
| **Apple Maps** | Opens the Apple Maps app. Always available. |
| **Google Maps** | Opens the Google Maps app. **Must be installed** — if it isn't, nothing happens. |

This setting only affects the maps deep link from station info. It has no effect on URL schemes or any other part of the app.

---

## Station Data

The app maintains a local cache of all UK rail stations (name, CRS code, coordinates, and operator). This allows the search to work instantly and offline, without making an API call for every keystroke.

### Last Updated

Timestamp of the most recent successful cache refresh.

### Stations

Count of stations currently in the cache. Typically ~2,600 for the full UK network.

### Refresh Now

Forces an immediate re-download of the station list from the API. Use this if:
- A station name has changed (e.g. a rebrand).
- A new station has opened and doesn't appear in search.
- The count looks wrong and you suspect a corrupt cache.

Normal usage doesn't require manual refreshes — the data changes rarely.

---

## Favourites Backup

### Export Favourites

Serialises your current favourites list to a JSON file and opens the system share sheet, letting you save it to Files, AirDrop it, or attach it to an email.

The exported file can be used to:
- Back up your favourites before reinstalling.
- Transfer favourites to another device.
- Share a set of boards with someone else.
- Hand-craft a favourites list to import.

### Import Favourites

Opens the Files picker. Select a valid Departure Board export file and the app will:
1. Read the JSON.
2. Add any boards not already in your favourites list.
3. Skip any that already exist.
4. Leave your existing favourites untouched and in their original order.

The import result is shown inline: green checks for added boards, minus circles for skipped ones.

---

## Export / Import JSON Format

The exported file is a plain JSON object. You can create or edit one in any text editor.

### Top-Level Structure

```json
{
  "favourites": [
    "MAN-dep",
    "LDS-arr",
    "LIV-dep-to-EUS",
    "EUS-arr-from-LIV"
  ]
}
```

The file must have a single key `favourites` whose value is an array of **board ID strings**.

### Board ID String Format

Each string encodes one favourite board using hyphen-separated components:

```
{CRS}-{type}
{CRS}-{type}-{direction}-{filterCRS}
```

| Component | Values | Description |
|-----------|--------|-------------|
| `CRS` | Any 3-letter UK rail CRS code (uppercase) | The station the board is for |
| `type` | `dep` or `arr` | Departures or arrivals |
| `direction` | `to` or `from` | Filter direction (only for filtered boards) |
| `filterCRS` | Any 3-letter CRS code (uppercase) | The station to filter by (only for filtered boards) |

### Examples

| ID string | Meaning |
|-----------|---------|
| `MAN-dep` | Manchester Piccadilly — Departures |
| `LDS-arr` | Leeds — Arrivals |
| `LIV-dep-to-EUS` | Liverpool Lime Street Departures — filtered to trains going **to** London Euston |
| `EUS-arr-from-LIV` | London Euston Arrivals — filtered to trains arriving **from** Liverpool Lime Street |
| `YRK-dep-from-LDS` | York Departures — filtered to trains originating **from** Leeds |

### Rules

- CRS codes are case-sensitive and must be uppercase (e.g. `MAN`, not `man`).
- Unknown CRS codes are silently rejected on import — the app validates each entry against its cached station list.
- Duplicate entries are skipped; the existing entry is kept.
- Order in the array determines order in the favourites list.
- There is no maximum number of favourites enforced by the format, though very long lists may affect performance of the Next Service feature.

### Minimal Valid File

```json
{"favourites":["MAN-dep"]}
```

### Filtering Direction Reference

| `direction` value | Meaning |
|-------------------|---------|
| `to` | Show only trains whose **destination** includes `filterCRS` |
| `from` | Show only trains that **originated from** `filterCRS` |

`from` is the default direction used by the URL scheme when `filterType` is omitted, but both must be explicit in the JSON format.

---

## URL Schemes

URL schemes are covered in detail within the app's own Settings screen. They allow you to open any board directly from Safari, the Shortcuts app, or any third-party app.

Quick reference:

| URL | Opens |
|-----|-------|
| `departure://departures/MAN` | Manchester Piccadilly Departures |
| `departure://arrivals/LDS` | Leeds Arrivals |
| `departure://station/YRK` | York Station Information sheet |
| `departure://departures/LIV?filter=EUS&filterType=to` | Liverpool departures filtered to Euston |
| `departure://arrivals/EUS?filter=LIV` | Euston arrivals filtered from Liverpool (filterType defaults to `from`) |
| `departure://service/{CRS}/{serviceId}` | Jump directly to a specific service by its ID |

CRS codes used in URL schemes are the same three-letter codes shown throughout the app.
