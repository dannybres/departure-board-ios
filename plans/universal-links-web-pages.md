# Universal Links & Web Pages Spec

## How Universal Links Work

1. Host an `apple-app-site-association` (AASA) JSON file at `https://yourdomain.com/.well-known/apple-app-site-association`
2. iOS app declares the domain in its **Associated Domains** entitlement (`applinks:yourdomain.com`)
3. When a user taps a link to your domain, iOS checks if the app is installed — if yes, it opens the app directly; if not, it opens Safari

No redirect, no interstitial — seamless.

## AASA File

Hosted at `https://yourdomain.com/.well-known/apple-app-site-association` (no file extension, served as `application/json`):

```json
{
  "applinks": {
    "apps": [],
    "details": [
      {
        "appID": "TEAMID.com.yourbundle.departureboard",
        "paths": ["/*"]
      }
    ]
  }
}
```

## Pages Required

### 1. Landing Page
- **URL:** `/`
- **Web:** Landing page explaining the app, link to App Store
- **App:** Opens app to home screen
- **Share use case:** "Check out this app"

### 2. Station Info
- **URL:** `/station/{CRS}` e.g. `/station/WAT`
- **Web:** Station information page (name, facilities, links)
- **App:** Opens station info sheet
- **Share use case:** "Here's info about Waterloo"

### 3. Station Departures
- **URL:** `/departures/{CRS}` e.g. `/departures/WAT`
- **Web:** Shows live departure board for that station
- **App:** Opens DepartureBoardView with departures selected
- **Share use case:** "Departures from Waterloo"

### 4. Station Arrivals
- **URL:** `/arrivals/{CRS}` e.g. `/arrivals/WAT`
- **Web:** Shows live arrivals board for that station
- **App:** Opens DepartureBoardView with arrivals selected
- **Share use case:** "Arrivals at Waterloo"

### 5. Filtered Departures (calling at)
- **URL:** `/departures/{CRS}/to/{filterCRS}` e.g. `/departures/WAT/to/CLJ`
- **Web:** Shows departures from WAT calling at CLJ
- **App:** Opens board with filter applied
- **Share use case:** "Trains from WAT calling at CLJ"

### 6. Filtered Arrivals (from)
- **URL:** `/arrivals/{CRS}/from/{filterCRS}` e.g. `/arrivals/WAT/from/CLJ`
- **Web:** Shows arrivals at WAT from CLJ
- **App:** Opens board with filter applied
- **Share use case:** "Trains arriving WAT from CLJ"

### 7. Service Detail
- **URL:** `/service/{serviceID}` e.g. `/service/abc123`
- **Web:** Full calling point timeline for a specific service
- **App:** Opens ServiceDetailView
- **Share use case:** "Look at this specific train"

## Summary

| # | Page | URL Pattern |
|---|---|---|
| 1 | Landing | `/` |
| 2 | Station Info | `/station/{CRS}` |
| 3 | Departures | `/departures/{CRS}` |
| 4 | Arrivals | `/arrivals/{CRS}` |
| 5 | Filtered Departures | `/departures/{CRS}/to/{CRS}` |
| 6 | Filtered Arrivals | `/arrivals/{CRS}/from/{CRS}` |
| 7 | Service Detail | `/service/{serviceID}` |

## iOS App Side

1. Add `applinks:yourdomain.com` to Associated Domains entitlement
2. Handle `NSUserActivity` in app/scene delegate to parse incoming URL and navigate to the correct view
