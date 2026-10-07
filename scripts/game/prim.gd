class_name Prim
extends RefCounted
## Helpers for building placeholder geometry in code. Every mesh gets the
## shared "bent world" material (one per colour), so all of it curves with the
## road. Swap this file's internals when real models arrive.

const BENT_SHADER: Shader = preload("res://assets/materials/bent.gdshader")
## Bent meshes move far from their original bounds, so widen culling bounds.
const CULL_MARGIN: float = 60.0

static var _materials: Dictionary = {}


## An uncached material, for things whose colour changes at runtime (lamps).
static func new_material(color: Color) -> ShaderMaterial:
	var shader_material := ShaderMaterial.new()
	shader_material.shader = BENT_SHADER
	shader_material.set_shader_parameter("albedo", color)
	return shader_material


static func material(color: Color) -> ShaderMaterial:
	if not _materials.has(color):
		var shader_material := ShaderMaterial.new()
		shader_material.shader = BENT_SHADER
		shader_material.set_shader_parameter("albedo", color)
		_materials[color] = shader_material
	return _materials[color]


static func box(parent: Node3D, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	return _add_mesh(parent, mesh, pos, color)


static func cylinder(parent: Node3D, top_radius: float, bottom_radius: float, height: float,
		pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 10
	mesh.rings = 1
	return _add_mesh(parent, mesh, pos, color)


static func sphere(parent: Node3D, radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 12
	mesh.rings = 6
	return _add_mesh(parent, mesh, pos, color)


## A flat sign facing +Z (toward an approaching player) showing a texture.
static func textured_quad(parent: Node3D, size: Vector2, pos: Vector3, texture: Texture2D) -> MeshInstance3D:
	var mesh := QuadMesh.new()
	mesh.size = size
	var instance := _add_mesh(parent, mesh, pos, Color.WHITE)
	var shader_material := ShaderMaterial.new()
	shader_material.shader = BENT_SHADER
	shader_material.set_shader_parameter("use_texture", true)
	shader_material.set_shader_parameter("albedo_texture", texture)
	instance.material_override = shader_material
	return instance


static func box_shape(parent: Node3D, size: Vector3, pos: Vector3) -> CollisionShape3D:
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = pos
	parent.add_child(collision)
	return collision


static func sphere_shape(parent: Node3D, radius: float, pos: Vector3) -> CollisionShape3D:
	var shape := SphereShape3D.new()
	shape.radius = radius
	var collision := CollisionShape3D.new()
	collision.shape = shape
	collision.position = pos
	parent.add_child(collision)
	return collision


static func _add_mesh(parent: Node3D, mesh: Mesh, pos: Vector3, color: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	instance.mesh = mesh
	instance.material_override = material(color)
	instance.position = pos
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	instance.extra_cull_margin = CULL_MARGIN
	parent.add_child(instance)
	return instance
