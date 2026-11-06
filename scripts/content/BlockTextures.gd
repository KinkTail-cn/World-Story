extends RefCounted

## 方块高清日系动漫像素纹理与网格工坊
## 为游戏内 20 种方块程序化生成标准的 48x16 像素艺术贴图与 3D 立方体网格
## 贴图布局：[0..15]: 侧面, [16..31]: 顶面, [32..47]: 底面

static var _texture_cache: Dictionary = {}
static var _material_cache: Dictionary = {}
static var _mesh_cache: Dictionary = {}
static var _atlas_texture: ImageTexture = null

## 获取包含全部 20 种方块贴图的完整世界地形图集 (48 x 320)
static func get_atlas_texture() -> ImageTexture:
	if _atlas_texture != null:
		return _atlas_texture
		
	var atlas_img := Image.create(48, 20 * 16, false, Image.FORMAT_RGBA8)
	for id in range(1, 21):
		var b_img := _generate_block_image(id)
		var dst_y: int = (id - 1) * 16
		atlas_img.blit_rect(b_img, Rect2i(0, 0, 48, 16), Vector2i(0, dst_y))
		
	_atlas_texture = ImageTexture.create_from_image(atlas_img)
	return _atlas_texture

## 获取方块专属的 48x16 日系像素贴图
static func get_texture(block_id: int) -> ImageTexture:
	if _texture_cache.has(block_id):
		return _texture_cache[block_id]
		
	var img := _generate_block_image(block_id)
	var tex := ImageTexture.create_from_image(img)
	_texture_cache[block_id] = tex
	return tex

## 获取方块专属的标准 3D 渲染材质
static func get_material(block_id: int) -> StandardMaterial3D:
	if _material_cache.has(block_id):
		return _material_cache[block_id]
		
	var mat := StandardMaterial3D.new()
	mat.albedo_texture = get_texture(block_id)
	mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	mat.roughness = 0.82
	mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	
	if block_id == 16: # 纯净玻璃：通透半透明与双面渲染
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_DISABLED
		mat.roughness = 0.15
	elif block_id == 12: # 生铁块：金属微反光
		mat.roughness = 0.45
		mat.metallic = 0.35
	elif block_id == 19: # 黑曜石：火山玻璃深邃微光
		mat.roughness = 0.35
		
	_material_cache[block_id] = mat
	return mat

## 构建标准带 6 面独立 UV 的体素立方体网格
static func create_block_mesh(sz: Vector3 = Vector3(0.32, 0.32, 0.32)) -> ArrayMesh:
	var key: String = "%.3f_%.3f_%.3f" % [sz.x, sz.y, sz.z]
	if _mesh_cache.has(key):
		return _mesh_cache[key]
		
	var hx: float = sz.x * 0.5
	var hy: float = sz.y * 0.5
	var hz: float = sz.z * 0.5
	
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	var uvs := PackedVector2Array()
	var indices := PackedInt32Array()
	
	# Sample texel centers inside each face tile, so its edges never read
	# the neighboring side/top/bottom tile in the shared texture.
	var u_side_0: float = 0.5 / 48.0
	var u_side_1: float = 15.5 / 48.0
	var u_top_0: float = 16.5 / 48.0
	var u_top_1: float = 31.5 / 48.0
	var u_bot_0: float = 32.5 / 48.0
	var u_bot_1: float = 47.5 / 48.0
	var v_start: float = 0.5 / 16.0
	var v_end: float = 15.5 / 16.0
	
	var faces := [
		# +Y (顶面, 第 1 单元: U ∈ [1/3, 2/3])
		[Vector3.UP, Vector3(-hx, hy, -hz), Vector3(hx, hy, -hz), Vector3(hx, hy, hz), Vector3(-hx, hy, hz), u_top_0, u_top_1],
		# -Y (底面, 第 2 单元: U ∈ [2/3, 1.0])
		[Vector3.DOWN, Vector3(-hx, -hy, hz), Vector3(hx, -hy, hz), Vector3(hx, -hy, -hz), Vector3(-hx, -hy, -hz), u_bot_0, u_bot_1],
		# +Z (南侧面/正面, 第 0 单元: U ∈ [0, 1/3])
		[Vector3.BACK, Vector3(-hx, hy, hz), Vector3(hx, hy, hz), Vector3(hx, -hy, hz), Vector3(-hx, -hy, hz), u_side_0, u_side_1],
		# -Z (北侧面/背面, 第 0 单元: U ∈ [0, 1/3])
		[Vector3.FORWARD, Vector3(hx, hy, -hz), Vector3(-hx, hy, -hz), Vector3(-hx, -hy, -hz), Vector3(hx, -hy, -hz), u_side_0, u_side_1],
		# -X (西侧面/左面, 第 0 单元: U ∈ [0, 1/3])
		[Vector3.LEFT, Vector3(-hx, hy, -hz), Vector3(-hx, hy, hz), Vector3(-hx, -hy, hz), Vector3(-hx, -hy, -hz), u_side_0, u_side_1],
		# +X (东侧面/右面, 第 0 单元: U ∈ [0, 1/3])
		[Vector3.RIGHT, Vector3(hx, hy, hz), Vector3(hx, hy, -hz), Vector3(hx, -hy, -hz), Vector3(hx, -hy, hz), u_side_0, u_side_1],
	]
	
	for f in faces:
		var n: Vector3 = f[0]
		var v0: Vector3 = f[1] # 左上
		var v1: Vector3 = f[2] # 右上
		var v2: Vector3 = f[3] # 右下
		var v3: Vector3 = f[4] # 左下
		var u0: float = f[5]
		var u1: float = f[6]
		
		var base_idx: int = vertices.size()
		# 遵循 Godot 原生顺时针 (CW) 四边形正面定义，完美支持 Backface Culling
		vertices.append(v0); normals.append(n); uvs.append(Vector2(u0, v_start))
		vertices.append(v1); normals.append(n); uvs.append(Vector2(u1, v_start))
		vertices.append(v2); normals.append(n); uvs.append(Vector2(u1, v_end))
		vertices.append(v3); normals.append(n); uvs.append(Vector2(u0, v_end))
		
		# 两个三角形顺时针绕序 (0->1->3, 1->2->3)
		indices.append(base_idx + 0)
		indices.append(base_idx + 1)
		indices.append(base_idx + 3)
		indices.append(base_idx + 1)
		indices.append(base_idx + 2)
		indices.append(base_idx + 3)
		
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices
	
	var arr_mesh := ArrayMesh.new()
	arr_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	_mesh_cache[key] = arr_mesh
	return arr_mesh

# -----------------------------------------------------------------------------
# 内部像素绘图辅助
# -----------------------------------------------------------------------------
static func _pset(img: Image, ox: int, x: int, y: int, c: Color) -> void:
	if x >= 0 and x < 16 and y >= 0 and y < 16:
		img.set_pixel(ox + x, y, c)

static func _pfill(img: Image, ox: int, x0: int, y0: int, w: int, h: int, c: Color) -> void:
	for dy in range(h):
		for dx in range(w):
			_pset(img, ox, x0 + dx, y0 + dy, c)

# Broad ground surfaces use a quiet base with sparse, low-contrast clusters.
# A local seed avoids the repeated diagonal bands of per-pixel modulo patterns.
static func _soft_ground_tile(img: Image, ox: int, base: Color, light: Color, dark: Color, seed_value: int, marks: int) -> void:
	_pfill(img, ox, 0, 0, 16, 16, base)
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	for _mark in range(marks):
		var x := rng.randi_range(0, 15)
		var y := rng.randi_range(0, 15)
		var color := light if rng.randf() < 0.5 else dark
		var width := rng.randi_range(2, 3)
		var height := rng.randi_range(1, 2)
		for dy in range(height):
			for dx in range(width):
				if (dx == 0 and dy == 0) or rng.randf() < 0.65:
					_pset(img, ox, posmod(x + dx, 16), posmod(y + dy, 16), color)

## 核心像素生成算法：输出 48x16 图像
static func _generate_block_image(id: int) -> Image:
	var img := Image.create(48, 16, false, Image.FORMAT_RGBA8)
	img.fill(Color.BLACK)
	
	match id:
		1: # 草方块
			# 底面泥土
			_pfill(img, 32, 0, 0, 16, 16, Color("#82522c"))
			for y in range(16):
				for x in range(16):
					var n: int = int(posmod(x * 31 + y * 73, 100))
					if n < 18: _pset(img, 32, x, y, Color("#6c4221"))
					elif n < 32: _pset(img, 32, x, y, Color("#986337"))
					
			# 顶面以柔和草绿为主，仅保留少量成簇的浅深草色。
			_soft_ground_tile(img, 16, Color("#739a60"), Color("#7a9f67"), Color("#6e955c"), 1107, 12)
					
			# 侧面：上部锯齿垂草 + 下部泥土
			for y in range(16):
				for x in range(16):
					var n: int = int(posmod(x * 19 + y * 53, 100))
					var dc: Color = Color("#82522c")
					if n < 18: dc = Color("#6c4221")
					elif n < 32: dc = Color("#986337")
					_pset(img, 0, x, y, dc)
			var grass_depth := [5, 5, 6, 6, 5, 4, 4, 5, 5, 6, 6, 5, 5, 4, 4, 5]
			for x in range(16):
				var d: int = grass_depth[x]
				for y in range(d):
					var gc: Color = Color("#739a60")
					if y == d - 1: gc = Color("#6e955c")
					elif y == 2 and x in [2, 3, 10, 11]: gc = Color("#7a9f67")
					_pset(img, 0, x, y, gc)

		2: # 泥土
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var n: int = int(posmod(x * 37 + y * 67 + ox * 13, 100))
						var c: Color = Color("#82522c")
						if n < 18: c = Color("#6b401f")
						elif n < 34: c = Color("#986438")
						elif n < 42: c = Color("#aa7548")
						elif n < 48: c = Color("#593316")
						_pset(img, ox, x, y, c)

		3: # 原木
			# 顶面与底面（同心年轮与树皮外圈）
			for ox in [16, 32]:
				for y in range(16):
					for x in range(16):
						var dx: float = float(x) - 7.5
						var dy: float = float(y) - 7.5
						var dist: float = sqrt(dx * dx + dy * dy)
						var c: Color = Color("#d8b276")
						if dist >= 6.4: c = Color("#4a2b15")
						elif dist >= 5.6: c = Color("#381e0d")
						elif dist >= 4.2 and dist <= 5.0: c = Color("#b88c4d")
						elif dist >= 2.2 and dist <= 2.9: c = Color("#b88c4d")
						elif dist <= 1.2: c = Color("#946b33")
						elif int(dist * 2.0) % 2 == 0: c = Color("#ceaa6e")
						_pset(img, ox, x, y, c)
			# 侧面树皮垂直木纹
			for y in range(16):
				for x in range(16):
					var col_type: int = x % 4
					var c: Color = Color("#643f23")
					if col_type == 0: c = Color("#462913")
					elif col_type == 1: c = Color("#784d2b")
					elif col_type == 2: c = Color("#5a371c")
					else: c = Color("#6b4426")
					if (x + y * 7) % 11 == 0: c = Color("#40240f")
					_pset(img, 0, x, y, c)

		4: # 树叶
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var n: int = int(posmod(x * 43 + y * 83 + ox * 19, 100))
						var c: Color = Color("#59894f")
						if n < 22: c = Color("#739f62")
						elif n < 40: c = Color("#659458")
						elif n < 62: c = Color("#4d7846")
						elif n < 78: c = Color("#40643d")
						elif n < 85: c = Color("#365636")
						_pset(img, ox, x, y, c)

		5: # 石头
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var n: int = int(posmod(x * 53 + y * 97 + ox * 29, 100))
						var c: Color = Color("#7b8b98")
						if n < 18: c = Color("#667683")
						elif n < 34: c = Color("#8f9fa9")
						elif n < 44: c = Color("#566470")
						elif n < 52: c = Color("#a2b2bd")
						_pset(img, ox, x, y, c)

		6: # 沙子
			for ox in [0, 16, 32]:
				_soft_ground_tile(img, ox, Color("#c8b58e"), Color("#cbb993"), Color("#c3b08a"), 6203 + ox, 9)

		7: # 木板
			for ox in [0, 16, 32]:
				for y in range(16):
					var plank_idx: int = y / 4
					var py: int = y % 4
					for x in range(16):
						var c: Color = Color("#bc894c")
						if py == 3: c = Color("#744c20")
						elif py == 0: c = Color("#d69f5c")
						else:
							var n: int = int(posmod(x * 19 + plank_idx * 43, 100))
							if n < 20: c = Color("#af7c40")
							elif n < 40: c = Color("#c79354")
						if (plank_idx % 2 == 0 and x == 1 and py == 1) or (plank_idx % 2 == 1 and x == 14 and py == 1):
							c = Color("#543414")
						_pset(img, ox, x, y, c)

		8: # 陶瓦（工字红砖）
			for ox in [0, 16, 32]:
				for y in range(16):
					var row: int = y / 4
					var ry: int = y % 4
					for x in range(16):
						var c: Color = Color("#ba402c")
						if ry == 3: c = Color("#662014")
						elif ry == 0: c = Color("#cf543e")
						else:
							var split_x: int = 7 if (row % 2 == 0) else 15
							if x == split_x or (row % 2 == 1 and x == 7):
								c = Color("#662014")
							else:
								var n: int = int(posmod(x * 29 + y * 61 + ox * 11, 100))
								if n < 20: c = Color("#a83624")
								elif n < 40: c = Color("#c84c36")
						_pset(img, ox, x, y, c)

		9: # 高纯生铁矿
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var n: int = int(posmod(x * 53 + y * 97 + ox * 29, 100))
						var c: Color = Color("#7a8894")
						if n < 20: c = Color("#667683")
						elif n < 38: c = Color("#8f9fa9")
						_pset(img, ox, x, y, c)
				var spots := [Vector2i(3, 4), Vector2i(10, 2), Vector2i(7, 9), Vector2i(2, 11), Vector2i(11, 12)]
				for sp in spots:
					_pfill(img, ox, sp.x, sp.y, 3, 2, Color("#d99666"))
					_pset(img, ox, sp.x, sp.y, Color("#ffdfc4"))
					_pset(img, ox, sp.x + 1, sp.y, Color("#efa878"))
					_pset(img, ox, sp.x + 2, sp.y + 1, Color("#8c4f28"))
					_pset(img, ox, sp.x, sp.y + 1, Color("#b36a3e"))

		10: # 煤矿石
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var n: int = int(posmod(x * 53 + y * 97 + ox * 29, 100))
						var c: Color = Color("#7a8894")
						if n < 20: c = Color("#667683")
						elif n < 38: c = Color("#8f9fa9")
						_pset(img, ox, x, y, c)
				var spots := [Vector2i(2, 3), Vector2i(9, 3), Vector2i(6, 8), Vector2i(3, 11), Vector2i(11, 11)]
				for sp in spots:
					_pfill(img, ox, sp.x, sp.y, 3, 2, Color("#222228"))
					_pset(img, ox, sp.x, sp.y, Color("#5e5e6e"))
					_pset(img, ox, sp.x + 1, sp.y, Color("#363640"))
					_pset(img, ox, sp.x + 2, sp.y + 1, Color("#141418"))
					_pset(img, ox, sp.x, sp.y + 1, Color("#1a1a20"))

		11: # 金矿石
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var n: int = int(posmod(x * 47 + y * 89 + ox * 23, 100))
						var c: Color = Color("#6e7c88")
						if n < 20: c = Color("#5a6873")
						elif n < 38: c = Color("#82909b")
						_pset(img, ox, x, y, c)
				var spots := [Vector2i(3, 2), Vector2i(10, 4), Vector2i(6, 9), Vector2i(2, 10), Vector2i(11, 11)]
				for sp in spots:
					_pfill(img, ox, sp.x, sp.y, 3, 2, Color("#f2be22"))
					_pset(img, ox, sp.x, sp.y, Color("#fff4a8"))
					_pset(img, ox, sp.x + 1, sp.y, Color("#ffda48"))
					_pset(img, ox, sp.x + 2, sp.y + 1, Color("#b3820a"))
					_pset(img, ox, sp.x, sp.y + 1, Color("#d69f16"))

		12: # 生铁块
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var c: Color = Color("#cbdae8")
						if x == 0 or y == 0 or x == 15 or y == 15: c = Color("#92a4b8")
						elif x == 1 or y == 1: c = Color("#eef6ff")
						elif x == 14 or y == 14: c = Color("#a4b6c8")
						_pset(img, ox, x, y, c)
				var rivets := [Vector2i(3, 3), Vector2i(12, 3), Vector2i(3, 12), Vector2i(12, 12)]
				for rv in rivets:
					_pset(img, ox, rv.x, rv.y, Color("#ffffff"))
					_pset(img, ox, rv.x + 1, rv.y, Color("#76889a"))
					_pset(img, ox, rv.x, rv.y + 1, Color("#b0c0d0"))
					_pset(img, ox, rv.x + 1, rv.y + 1, Color("#5e7082"))
				_pfill(img, ox, 6, 7, 4, 2, Color("#dde8f4"))
				_pfill(img, ox, 7, 6, 2, 4, Color("#dde8f4"))

		13: # 鹅卵石
			for ox in [0, 16, 32]:
				_pfill(img, ox, 0, 0, 16, 16, Color("#424c56"))
				var stones := [
					[1, 1, 6, 4, Color("#8897a3")],
					[8, 1, 7, 5, Color("#74838f")],
					[1, 6, 5, 4, Color("#7a8995")],
					[7, 7, 8, 4, Color("#92a1ad")],
					[1, 11, 7, 4, Color("#82919d")],
					[9, 12, 6, 3, Color("#768591")]
				]
				for st in stones:
					var sx: int = st[0]
					var sy: int = st[1]
					var sw: int = st[2]
					var sh: int = st[3]
					var sc: Color = st[4]
					_pfill(img, ox, sx, sy, sw, sh, sc)
					for ix in range(sw): _pset(img, ox, sx + ix, sy, sc.lightened(0.18))
					for iy in range(sh): _pset(img, ox, sx, sy + iy, sc.lightened(0.15))
					for ix in range(sw): _pset(img, ox, sx + ix, sy + sh - 1, sc.darkened(0.2))
					for iy in range(sh): _pset(img, ox, sx + sw - 1, sy + iy, sc.darkened(0.2))

		14: # 石砖
			for ox in [0, 16, 32]:
				for y in range(16):
					var row: int = y / 5
					var ry: int = y % 5
					for x in range(16):
						var c: Color = Color("#82909a")
						if ry == 4: c = Color("#4a545c")
						elif ry == 0: c = Color("#a2b0ba")
						else:
							var split_x: int = 7 if (row % 2 == 0) else 15
							if x == split_x or (row % 2 == 1 and x == 7):
								c = Color("#4a545c")
							else:
								var n: int = int(posmod(x * 37 + y * 71, 100))
								if n < 18: c = Color("#74828c")
								elif n < 34: c = Color("#92a0aa")
						_pset(img, ox, x, y, c)

		15: # 粗糙花岗岩
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var n: int = int(posmod(x * 61 + y * 113 + ox * 41, 100))
						var c: Color = Color("#964e40")
						if n < 26: c = Color("#be6f60")
						elif n < 48: c = Color("#844033")
						elif n < 62: c = Color("#db9b8f")
						elif n < 76: c = Color("#422018")
						elif n < 85: c = Color("#f4d6d0")
						_pset(img, ox, x, y, c)

		16: # 纯净玻璃
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var c := Color(0.45, 0.78, 0.92, 0.42)
						if x == 0 or y == 0 or x == 15 or y == 15:
							c = Color(0.88, 0.95, 1.0, 0.85)
						var diag1: int = x + y
						var diag2: int = x + y - 6
						if diag1 == 8 or diag1 == 9 or diag2 == 10:
							c = Color(1.0, 1.0, 1.0, 0.85)
						elif diag1 == 7 or diag1 == 10:
							c = Color(0.85, 0.95, 1.0, 0.62)
						_pset(img, ox, x, y, c)

		17: # 砂岩
			for ox in [16, 32]:
				for y in range(16):
					for x in range(16):
						var n: int = int(posmod(x * 41 + y * 79, 100))
						var c: Color = Color("#bca67b")
						if n < 20: c = Color("#b29b72")
						elif n < 38: c = Color("#c5b188")
						_pset(img, ox, x, y, c)
			for y in range(16):
				for x in range(16):
					var c: Color = Color("#bca67b")
					if y >= 5 and y <= 9: c = Color("#b09a72")
					elif y >= 10: c = Color("#b7a079")
					if y == 4 or y == 9: c = Color("#8f7c5b")
					elif y == 5 or y == 10: c = Color("#ceba94")
					_pset(img, 0, x, y, c)

		18: # 高山雪块
			for y in range(16):
				for x in range(16):
					var n: int = int(posmod(x * 37 + y * 73, 100))
					var c: Color = Color("#f7fbff")
					if n < 20: c = Color("#e8f2fc")
					elif n < 35: c = Color("#ffffff")
					_pset(img, 16, x, y, c)
			_pfill(img, 32, 0, 0, 16, 16, Color("#dce9f8"))
			for y in range(16):
				for x in range(16):
					var c: Color = Color("#e2eeff")
					if y < 6:
						c = Color("#f7fbff")
						if (x + y) % 5 == 0: c = Color("#ffffff")
					elif y >= 11: c = Color("#c8daf0")
					if y == 5 and (x % 3 != 0): c = Color("#b8cee8")
					_pset(img, 0, x, y, c)

		19: # 黑曜石
			for ox in [0, 16, 32]:
				for y in range(16):
					for x in range(16):
						var n: int = int(posmod(x * 59 + y * 107 + ox * 31, 100))
						var c: Color = Color("#171124")
						if n < 18: c = Color("#2e1c46")
						elif n < 28: c = Color("#4b266e")
						elif n < 36: c = Color("#6c349a")
						elif n < 42: c = Color("#944cd4")
						elif n < 55: c = Color("#0f0b18")
						_pset(img, ox, x, y, c)

		20: # 工作台
			_pfill(img, 16, 0, 0, 16, 16, Color("#b88246"))
			for y in range(16):
				for x in range(16):
					if x == 5 or x == 10 or y == 5 or y == 10:
						_pset(img, 16, x, y, Color("#5e3a18"))
					elif x == 0 or y == 0 or x == 15 or y == 15:
						_pset(img, 16, x, y, Color("#7c4e22"))
					elif (x + y * 3) % 7 == 0:
						_pset(img, 16, x, y, Color("#c79354"))
			var corners := [Vector2i(0, 0), Vector2i(14, 0), Vector2i(0, 14), Vector2i(14, 14)]
			for cn in corners:
				_pfill(img, 16, cn.x, cn.y, 2, 2, Color("#d6a83e"))
				_pset(img, 16, cn.x, cn.y, Color("#ffea88"))
			_pfill(img, 32, 0, 0, 16, 16, Color("#7a4c22"))
			_pfill(img, 0, 0, 0, 16, 16, Color("#9e6b36"))
			for i in range(16):
				_pset(img, 0, i, 0, Color("#5a3414"))
				_pset(img, 0, i, 15, Color("#5a3414"))
				_pset(img, 0, 0, i, Color("#5a3414"))
				_pset(img, 0, 15, i, Color("#5a3414"))
			_pfill(img, 0, 3, 4, 3, 2, Color("#c48e4a"))
			_pset(img, 0, 4, 5, Color("#422008"))
			for sy in range(6, 12):
				_pset(img, 0, 4, sy, Color("#d0dce8"))
				if sy % 2 == 0: _pset(img, 0, 5, sy, Color("#92a4b8"))
			_pfill(img, 0, 10, 4, 4, 2, Color("#687684"))
			_pset(img, 0, 10, 4, Color("#b2c2d2"))
			for hy in range(6, 12):
				_pset(img, 0, 11, hy, Color("#7c4e24"))
				
		_:
			img.fill(Color("#888888"))
			
	return img
