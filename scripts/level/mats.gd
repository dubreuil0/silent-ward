class_name Mats
extends RefCounted
## Poly Haven PBR texture'larından materyal kütüphanesi.

## Her texture'ın dünya üzerinde kaç metrede bir tekrarlandığı.
const TEX_SIZE := {
	"floor_hall": 2.0,
	"floor_ward": 2.5,
	"floor_office": 2.0,
	"floor_base": 3.0,
	"wall_hall": 2.5,
	"wall_ward": 2.5,
	"wall_tile": 1.6,
	"wall_office": 2.0,
	"wall_base": 3.0,
	"ceiling": 3.0,
	"door_wood": 1.0,
	"metal_rust": 1.0,
	"metal_green": 1.5,
}

## Kir ve yaşlılık hissi için hafif renk tonlamaları.
const TINT := {
	"wall_hall": Color(0.78, 0.82, 0.76),
	"wall_ward": Color(0.8, 0.8, 0.74),
	"ceiling": Color(0.7, 0.7, 0.66),
	"floor_hall": Color(0.85, 0.85, 0.8),
}

static var _cache: Dictionary = {}


## world_uv: UV'ler metre cinsinden üretilmişse texture boyutuna göre ölçekler.
static func pbr(id: String, world_uv := true) -> StandardMaterial3D:
	var key := "%s_%s" % [id, world_uv]
	if _cache.has(key):
		return _cache[key]
	var m := StandardMaterial3D.new()
	var base := "res://assets/textures/%s_" % id
	m.albedo_texture = load(base + "albedo.jpg")
	m.albedo_color = TINT.get(id, Color.WHITE)
	m.normal_enabled = true
	m.normal_texture = load(base + "normal.jpg")
	m.normal_scale = 1.2
	var arm: Texture2D = load(base + "arm.jpg")
	m.roughness_texture = arm
	m.roughness_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_GREEN
	m.metallic_texture = arm
	m.metallic_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_BLUE
	m.metallic = 1.0
	m.ao_enabled = true
	m.ao_texture = arm
	m.ao_texture_channel = BaseMaterial3D.TEXTURE_CHANNEL_RED
	m.ao_light_affect = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if world_uv:
		var s: float = 1.0 / float(TEX_SIZE.get(id, 2.0))
		m.uv1_scale = Vector3(s, s, s)
	_cache[key] = m
	return m


## Nesneler için triplanar PBR (UV gerektirmez).
static func triplanar(id: String, scale := 1.0) -> StandardMaterial3D:
	var key := "tri_%s_%s" % [id, scale]
	if _cache.has(key):
		return _cache[key]
	var m := pbr(id, false).duplicate() as StandardMaterial3D
	m.uv1_triplanar = true
	m.uv1_world_triplanar = false
	m.uv1_triplanar_sharpness = 4.0
	m.uv1_scale = Vector3.ONE * scale
	m.cull_mode = BaseMaterial3D.CULL_BACK
	_cache[key] = m
	return m


static func plain(color: Color, roughness := 0.8, metallic := 0.0, emission := Color.BLACK, emission_energy := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = roughness
	m.metallic = metallic
	if emission_energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = emission_energy
	return m
