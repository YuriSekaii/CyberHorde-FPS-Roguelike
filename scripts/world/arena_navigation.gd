extends NavigationRegion3D

# Bakes the ground-enemy navmesh from the arena's static colliders on load, so pathing always matches
# the current layout (ramps up to the center platform, cover, pillars) without a stored bake going stale.
func _ready() -> void:
	bake_navigation_mesh(false)
