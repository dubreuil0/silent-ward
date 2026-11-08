extends SceneTree
## Geliştirme aracı: dil değişince çevirilerin doğru döndüğünü doğrular.
## godot --headless --path . --script res://tools/i18n_check.gd

func _init() -> void:
	I18n.setup()
	var keys := ["Yeni Oyun", "Ayarlar", "Kilitli", "menu.help", "note.n1.title", "KAÇ"]
	var fails := 0
	for loc in ["en", "tr", "en", "tr"]:
		TranslationServer.set_locale(loc)
		var line := "[%s] " % loc
		for k in keys:
			var t := TranslationServer.translate(k)
			line += "%s -> %s | " % [k, t.substr(0, 22).replace("\n", " ")]
		print(line)
		# Türkçe seçiliyken hiçbir anahtar İngilizceye dönmemeli
		if loc == "tr":
			for k in ["Yeni Oyun", "Ayarlar", "Kilitli", "KAÇ"]:
				if TranslationServer.translate(k) != k:
					fails += 1
					print("  [FAIL] tr seçiliyken '%s' çevrildi: %s" % [k, TranslationServer.translate(k)])
	print("I18N: %s" % ("BAŞARILI" if fails == 0 else "BAŞARISIZ (%d)" % fails))
	quit()
