extends RefCounted
## Find a free approach inside the real collision geometry, including alcove props.
static func approach(player: CharacterBody2D, eye: Node2D) -> Vector2:
	var original := player.global_position
	var query := PhysicsShapeQueryParameters2D.new()
	query.shape = player.get_node("CollisionShape2D").shape
	query.collision_mask = player.collision_mask
	query.exclude = [player.get_rid()]
	var space := player.get_world_2d().direct_space_state
	for distance in [40.0, 32.0, 24.0, 16.0, 12.0, 8.0]:
		for offset in [0.0, -8.0, 8.0, -12.0, 12.0]:
			var point: Vector2 = eye.global_position + eye.facing_normal * distance + eye.facing_normal.orthogonal() * offset
			query.transform = Transform2D(0.0, point)
			if not space.intersect_shape(query, 1).is_empty():
				continue
			player.global_position = point
			var contact := player.move_and_collide(-eye.facing_normal * distance, true, 0.01)
			if contact != null and contact.get_collider() == eye.wall and contact.get_normal().dot(eye.facing_normal) >= 0.95:
				player.global_position = original
				return point
	player.global_position = original
	return Vector2.INF

static func sweep(player: CharacterBody2D, eye: Node2D) -> bool:
	var point := approach(player, eye)
	if not point.is_finite():
		return false
	# Only the fixture moves to an approach; production advance performs the impact.
	player.global_position = point
	player.velocity = -eye.facing_normal * player.max_launch_speed
	for step in range(16):
		player.advance(1.0 / 60.0)
		if eye.state == eye.State.CLOSED:
			break
	return eye.state == eye.State.CLOSED
