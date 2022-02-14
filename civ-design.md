
= Civ 1

Requirement: 640 KB

80 * 50 standard size = 4000 bytes at least (4 K)

save files

- map: 14283 bytes (16 K)
- sve: 37856 bytes (32 K) (or about 10 * 4000, so 10 layers, see below)

10 layers:

- layer 0: terrain data, with 12 distinct values for the 12 valid terrain types
- layer 1: Per-Civ land occupation, mixed with land appeal for city-building (an overlay of layer 3)
- layer 2: area segmentation, with identifiers for separate land masses and inner seas
- layer 3: terrain-based land appeal for the computer to build cities
- layer 4: same as layer 5 below, but only what's visible to the player
- layer 5: terrain improvements (irrigation, mining, roads)
- layer 6: same as layer 7 below, but only what's visible to the player
- layer 7: railroads, rods, rivers, fortresses
- layer 8: Per-Civ land exploration and active units
- layer 9: Mini-map render (attached to next post because of attachments limit)

