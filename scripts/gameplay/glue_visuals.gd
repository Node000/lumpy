class_name GlueVisuals
## Shared blob-drawing helpers used by the placeholder liquid visuals
## (Player core, carried glue blobs and GlueBall). All values in local px.

const POINTS := 40


static func build_blob_points(radius: float, wobble: float = 0.0, wobble_speed: float = 4.0, time: float = 0.0, blob_count: int = 3) -> PackedVector2Array:
	var pts := PackedVector2Array()
	pts.resize(POINTS)
	var blob_phases := PackedFloat32Array()
	blob_phases.resize(blob_count)
	for i in blob_count:
		blob_phases[i] = TAU * (float(i) / blob_count) + time * wobble_speed
	for i in POINTS:
		var a := TAU * float(i) / POINTS
		var r := radius
		for b in blob_count:
			r += wobble * radius * 0.09 * sin(a * 3.0 + blob_phases[b] + i * 0.5)
		pts[i] = Vector2(cos(a), sin(a)) * maxf(r, 1.0)
	return pts


static func blob_segments(points: PackedVector2Array) -> PackedVector2Array:
	var n := points.size()
	if n < 2:
		return points
	var out := PackedVector2Array()
	out.resize(n)
	for i in n:
		out[i] = points[(i + 1) % n] - points[i]
	return out
