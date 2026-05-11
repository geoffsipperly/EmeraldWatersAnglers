# Yakima River — GPS Coordinates

Total length: ~214 river miles, mouth (Columbia River at Richland, WA) to headwaters (Keechelus Lake outlet, Cascade Mountains).

**Anchor points** (verified against published USGS / GNIS / municipal data):
- Mouth at Columbia confluence (Bateman Island, Richland)
- USGS 12510500 Yakima R at Kiona, WA (RM ~30)
- Prosser (Hwy 221 bridge, RM ~50)
- Mabton (RM ~65)
- Granger (RM ~80)
- Yakima city / Union Gap (RM ~105–110)
- Naches River confluence (RM ~117)
- Roza Dam, head of Yakima River Canyon (RM ~125)
- Ellensburg, I-90 bridge (RM ~150)
- USGS 12484500 Yakima R at Cle Elum, WA (RM ~180)
- Easton (RM ~195)
- Keechelus Lake outlet / dam (RM ~214, headwaters)

**All other points are interpolated approximations** following the river's known course between anchors. Verify against satellite imagery before relying on them for any safety-critical use.

```
River Name: Yakima River (Washington)
  Point 1 (mouth):        46.2497, -119.2287   # Columbia confluence, Bateman Island
  Point 2:                46.2730, -119.3050   # West Richland, Van Giesen St
  Point 3:                46.2870, -119.3700   # Horn Rapids ORV park area
  Point 4:                46.2950, -119.4280   # north loop toward Kiona
  Point 5:                46.2750, -119.4500   # river bends back south
  Point 6:                46.2580, -119.4700   # approaching Kiona
  Point 7:                46.2528, -119.4803   # USGS 12510500 Kiona gauge (RM ~30)
  Point 8:                46.2350, -119.5800   # heading SW toward Benton City
  Point 9:                46.2400, -119.6700   # Benton City vicinity
  Point 10:               46.2240, -119.7400   # approaching Prosser
  Point 11:               46.2069, -119.7639   # Prosser, Hwy 221 bridge (RM ~50)
  Point 12:               46.2200, -119.8400   # west of Prosser, river bends NW
  Point 13:               46.2300, -119.9100   # toward Mabton
  Point 14:               46.2086, -119.9917   # Mabton (RM ~65)
  Point 15:               46.2400, -120.0500   # north of Mabton, NW course
  Point 16:               46.2900, -120.1100   # between Sunnyside and Granger
  Point 17:               46.3415, -120.1859   # Granger (RM ~80)
  Point 18:               46.3700, -120.2700   # Granger to Zillah
  Point 19:               46.4150, -120.3100   # north of Zillah
  Point 20:               46.4500, -120.3700   # Wapato vicinity
  Point 21:               46.5000, -120.4400   # south Union Gap approaches
  Point 22:               46.5530, -120.4760   # Union Gap (RM ~105)
  Point 23:               46.6020, -120.5100   # Yakima city (RM ~110)
  Point 24:               46.6540, -120.5400   # Selah, north of Yakima
  Point 25:               46.6690, -120.5860   # Naches River confluence (RM ~117)
  Point 26:               46.6960, -120.5000   # entering Yakima River Canyon at Selah Gap
  Point 27:               46.7370, -120.4610   # Roza Dam, head of canyon (RM ~125)
  Point 28:               46.7850, -120.4700   # mid-canyon
  Point 29:               46.8500, -120.4900   # Umtanum Recreation Area
  Point 30:               46.9000, -120.5200   # canyon exit, Thrall area
  Point 31:               46.9500, -120.5400   # south Ellensburg approaches
  Point 32:               46.9890, -120.5410   # Ellensburg, I-90 bridge (RM ~150)
  Point 33:               47.0250, -120.6100   # west Ellensburg, NW
  Point 34:               47.0500, -120.6900   # toward Thorp
  Point 35:               47.0720, -120.8040   # Thorp
  Point 36:               47.1000, -120.8400   # Thorp to Cle Elum
  Point 37:               47.1450, -120.8800   # south of Cle Elum
  Point 38:               47.1955, -120.9398   # USGS 12484500 Cle Elum gauge (RM ~180)
  Point 39:               47.2150, -121.0100   # west of Cle Elum
  Point 40:               47.2350, -121.0900   # approaching Easton
  Point 41:               47.2410, -121.1870   # Easton (RM ~195)
  Point 42:               47.2700, -121.2400   # Easton to Keechelus
  Point 43:               47.3050, -121.3000   # Keechelus dam approach
  Point 44 (headwaters):  47.3270, -121.3300   # Keechelus Lake outlet / dam, Cascade Mtns
```

## Caveats

- Interpolated points (everything except the labeled anchor points) approximate the river's curving course at 5-river-mile intervals; they are **not** verified against the actual centerline and should be sanity-checked against satellite imagery before being committed to `RiverCoordinates.swift`.
- The Yakima has several diversion structures (Roza Dam, Sunnyside Diversion, Wapato Diversion) — points near these are placed on the mainstem channel, not the canals.
- Headwaters point is the Keechelus Dam outlet; the lake itself extends ~5 miles further NW into the Cascades.
