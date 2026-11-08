class_name ExactSlide
extends RefCounted
## move_and_slide() over exactly the time step the caller was given.
##
## CharacterBody3D.move_and_slide() takes no time step: it uses the engine's - the physics step inside
## a physics frame, the last rendered frame's delta outside one. In play every body moves inside a
## physics frame, so the two agree and this changes nothing. But a test that steps a body by hand
## (`e._physics_process(1.0 / 60.0)` after `await process_frame`) got whatever the last frame took -
## in an unthrottled headless run anything from a fraction of a millisecond up - so a brute set down
## 2.6 m off walked a different distance each run and the self-test's slam checks flaked
## (build-plan Phase 0: "enemies move by the exact frame step, not move_and_slide's own clock").
## Here the velocity is scaled for the one call so the body covers velocity x delta, then handed back
## in the caller's units (keeping what the slide did to it).


## Slide `body` by its velocity over `delta` seconds; returns move_and_slide()'s collided flag.
static func slide(body: CharacterBody3D, delta: float) -> bool:
	if delta <= 0.0:
		return false
	var engine_dt: float = body.get_physics_process_delta_time() if Engine.is_in_physics_frame() else body.get_process_delta_time()
	if absf(engine_dt - delta) <= 0.000001:
		return body.move_and_slide()
	if engine_dt <= 0.0:
		# no frame to scale against: move the exact distance by hand
		return body.move_and_collide(body.velocity * delta) != null
	var k: float = delta / engine_dt
	body.velocity *= k
	var hit: bool = body.move_and_slide()
	body.velocity /= k
	return hit
