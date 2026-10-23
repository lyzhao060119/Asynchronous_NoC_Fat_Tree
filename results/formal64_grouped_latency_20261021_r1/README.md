# Grouped 64-node latency curves

- `latency_unicast.png` / `.pdf`: Uniform Random, Bit Complement, Hotspot10.
- `latency_multicast.png` / `.pdf`: M5, M10, M-static.
- Both figures use linear axes, x = 0–300 Mflit/s/port. Unicast y = 1–40 ns; multicast y = 1–60 ns.
- Color denotes topology: blue M16, orange Mesh, green PFAT.
- Marker and line style denote benchmark: circle/solid, square/dashed, triangle/dash-dot, in the order above. Line width is 2 pt.
- Curve and legend markers use 6 pt symbols.
- Filled markers are near-lossless-window points; open markers are accepted pressure points. Values outside the displayed y-range are clipped, not replaced by the axis limit.
- Data: three-seed mean offer-to-last-destination-tail latency, including source queueing. Sync M16 is excluded.
- `plot_data.csv` retains every selected point and its sample standard deviation; `manifest.json` records source SHA-256, scales, point counts and output hashes. No smoothing or synthetic points.
- Layout uses two compact legends, shared typography, restrained grid lines and redundant marker/line coding for grayscale readability. PNG is 320 dpi; PDF is vector with embedded TrueType fonts.
- The plotting area height is 80% of its width (20% shorter than the preceding square version). Width and numerical axis ranges are unchanged.
