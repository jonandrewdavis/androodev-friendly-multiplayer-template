@tool
extends EditorScenePostImport

## Meshes in this model are skinned, so import-time physics uses the unposed
## vertices. Skin each visible mesh on the CPU and build trimesh collision from
## the posed triangles. Runs out-of-tree, so no MeshInstance3D baking helpers.

const COLLISION_BITS := 0xFF # layers 1-8


func _post_import(scene: Node) -> Object:
	for mi: MeshInstance3D in scene.find_children("*", "MeshInstance3D", true, false):
		if not mi.visible or mi.mesh == null:
			continue
		var faces := _posed_faces(mi)
		if faces.is_empty():
			continue
		var shape := ConcavePolygonShape3D.new()
		shape.set_faces(faces)
		var body := StaticBody3D.new()
		body.name = mi.name + "_col"
		body.collision_layer = COLLISION_BITS
		body.collision_mask = COLLISION_BITS
		var col := CollisionShape3D.new()
		col.name = "CollisionShape3D"
		col.shape = shape
		body.add_child(col)
		mi.add_child(body)
		body.owner = scene
		col.owner = scene
	return scene


## Returns triangle soup in the MeshInstance3D's local space.
func _posed_faces(mi: MeshInstance3D) -> PackedVector3Array:
	var skel := mi.get_node_or_null(mi.skeleton) as Skeleton3D
	var skin := mi.skin
	var bind_xforms: Array[Transform3D] = []
	var to_local := Transform3D.IDENTITY
	if skel != null and skin != null:
		# Skinned vertices end up in skeleton space; bring them into mi space.
		to_local = _rel_xform(mi, skel).affine_inverse()
		for i in skin.get_bind_count():
			var bone := skin.get_bind_bone(i)
			if bone < 0:
				bone = skel.find_bone(skin.get_bind_name(i))
			var pose := skel.get_bone_global_pose(bone) if bone >= 0 else Transform3D.IDENTITY
			bind_xforms.append(to_local * pose * skin.get_bind_pose(i))

	var out := PackedVector3Array()
	for s in mi.mesh.get_surface_count():
		var arrays := mi.mesh.surface_get_arrays(s)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arrays[Mesh.ARRAY_INDEX]
		var bones = arrays[Mesh.ARRAY_BONES]
		var weights = arrays[Mesh.ARRAY_WEIGHTS]
		var posed := verts
		if not bind_xforms.is_empty() and bones != null and weights != null and bones.size() > 0:
			var per: int = bones.size() / verts.size()
			posed = PackedVector3Array()
			posed.resize(verts.size())
			for v in verts.size():
				var p := Vector3.ZERO
				for k in per:
					var w: float = weights[v * per + k]
					if w > 0.0:
						p += (bind_xforms[bones[v * per + k]] * verts[v]) * w
				posed[v] = p
		if idx.is_empty():
			out.append_array(posed)
		else:
			for i in idx:
				out.append(posed[i])
	return out


## Transform of `node` relative to `ancestor_or_sibling_root` without being in-tree.
func _rel_xform(node: Node3D, other: Node3D) -> Transform3D:
	return _global(other).affine_inverse() * _global(node)


func _global(n: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	while n != null:
		if n is Node3D:
			t = (n as Node3D).transform * t
		n = n.get_parent()
	return t
