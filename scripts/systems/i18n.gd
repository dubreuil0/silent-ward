class_name I18n
extends RefCounted
## Türkçe / İngilizce çeviriler. Kısa metinlerde anahtar Türkçe metnin kendisidir;
## uzun metinler (notlar, yardım) kimlik anahtarı kullanır ve iki dilde de tanımlıdır.

const EN := {
	# --- menü ve ayarlar
	"SESSİZ KOĞUŞ": "SILENT WARD",
	"Saint Halvard Akıl Hastanesi  ·  1987": "Saint Halvard Asylum  ·  1987",
	"Yeni Oyun": "New Game",
	"Ayarlar": "Settings",
	"Nasıl Oynanır": "How to Play",
	"Çıkış": "Quit",
	"NASIL OYNANIR": "HOW TO PLAY",
	"Texture ve modeller: Poly Haven (CC0)  ·  Sesler prosedürel üretildi": "Textures and models: Poly Haven (CC0)  ·  Procedurally generated audio",
	"KAÇ": "RUN",
	"AYARLAR": "SETTINGS",
	"Dil / Language": "Language / Dil",
	"Fare hassasiyeti": "Mouse sensitivity",
	"Ana ses": "Master volume",
	"Parlaklık": "Brightness",
	"Tam ekran (F11)": "Fullscreen (F11)",
	"İpucu: Oyun karanlık olmak üzere tasarlandı. Parlaklığı,\nekranın en karanlık köşesi zar zor seçilene kadar ayarla.": "Tip: the game is meant to be dark. Adjust brightness until\nthe darkest corner of the screen is barely visible.",
	"Geri": "Back",

	# --- HUD
	"HEDEF": "OBJECTIVE",
	"FENER  %d%%": "FLASHLIGHT  %d%%",
	"  (kapalı)": "  (off)",
	"SİGORTA  %d / %d": "FUSES  %d / %d",
	"Nefesini tutuyorsun...": "Holding your breath...",
	"Yakında! NEFESİNİ TUT  [Sağ Tık / Boşluk]": "She's close! HOLD YOUR BREATH  [Right Click / Space]",
	"Saklanıyorsun   [E] Çık   [Sağ Tık] Nefesini tut": "Hiding   [E] Leave   [Right Click] Hold breath",
	"[E] / [ESC]  Kapat": "[E] / [ESC]  Close",
	"DURAKLATILDI": "PAUSED",
	"Okunan notlar: %d/%d    ·    Süre: %s": "Notes read: %d/%d    ·    Time: %s",
	"Devam et": "Resume",
	"Yeniden başla": "Restart",
	"Ana menü": "Main menu",
	"Masaüstüne çık": "Quit to desktop",
	"KAÇTIN": "YOU ESCAPED",
	"SENİ BULDU": "SHE FOUND YOU",
	"Süre: %s    ·    Sigorta: %d/%d    ·    Okunan notlar: %d/%d": "Time: %s    ·    Fuses: %d/%d    ·    Notes read: %d/%d",
	"Tekrar oyna": "Play again",
	"Tekrar dene": "Try again",

	# --- etkileşim
	"Al: %s": "Take: %s",
	"Sigorta": "Fuse",
	"Pil": "Battery",
	"Morg Anahtarı": "Morgue Key",
	"Ofis Anahtarı": "Office Key",
	"Bodrum Anahtarı": "Basement Key",
	"Sigorta bulundu (%d/%d)": "Fuse found (%d/%d)",
	"%s alındı.": "Picked up %s.",
	"Fener pili (+%45)": "Flashlight battery (+45%)",
	"Ana Kapı": "Main Door",
	"Ana Kapı (elektrik yok)": "Main Door (no power)",
	"Kilidi aç: %s": "Unlock: %s",
	"Kilitli": "Locked",
	"Kapıyı kapat": "Close door",
	"Kapıyı aç": "Open door",
	"%s kullanıldı.": "Used the %s.",
	"Kilitli. Bir anahtar gerekiyor.": "Locked. You need a key.",
	"Oku: %s": "Read: %s",
	"Dolaptan çık": "Leave locker",
	"Dolaba saklan": "Hide in locker",
	"Jeneratör çalışıyor": "Generator running",
	"Sigortaları tak ve jeneratörü çalıştır": "Insert fuses and start the generator",
	"Jeneratör (%d/%d sigorta)": "Generator (%d/%d fuses)",
	"Sigorta yuvaları boş. %d sigorta daha lazım.": "The fuse slots are empty. You need %d more.",
	"Pil bitti.": "The battery is dead.",
	"Fenerin pili bitti. Pil bul.": "Your flashlight died. Find a battery.",

	# --- seviye
	"Saint Halvard'dan çıkmanın bir yolunu bul.": "Find a way out of Saint Halvard.",
	"Kardeşin bu hastanede kayboldu. Kapı arkandan kilitlendi.": "Your sibling vanished in this hospital. The door locked behind you.",
	"[F] Fener   ·   [Shift] Koş   ·   [Ctrl] Eğil   ·   [E] Etkileşim": "[F] Flashlight   ·   [Shift] Run   ·   [Ctrl] Crouch   ·   [E] Interact",
	"Tüm sigortalar sende. Bodrumdaki jeneratörü çalıştır.": "You have every fuse. Start the generator in the basement.",
	"Sigortaları bul (%d/%d) ve bodrumdaki jeneratörü çalıştır.": "Find the fuses (%d/%d) and start the basement generator.",
	"Bir şey uyandı. Sessiz ol.": "Something woke up. Stay quiet.",
	"Ana kapı elektrikle kilitli. Elektriği geri getirmenin bir yolunu bul.": "The main door is electronically locked. Find a way to restore power.",
	"Kapı elektronik kilitli. Elektrik olmadan açılmıyor.": "The door is electronically locked. It won't open without power.",
	"KOŞ! Lobideki ana kapıya git!": "RUN! Get to the main door in the lobby!",
	"Elektrik geldi... ve alarmlar O'nu uyandırdı. KOŞ!": "The power is back... and the alarms woke Her. RUN!",
	"GERİ DÖN": "TURN BACK",
	"O DUYUYOR": "SHE HEARS",
	"SESSİZLİK": "SILENCE",
	"HASTALARIM BENİM": "THEY ARE MY PATIENTS",
	"IŞIĞI KAPAT": "TURN OFF THE LIGHT",
	"ÇIKIŞ": "EXIT",

	# --- uzun metinler
	"hud.controls": "\nWASD Move  ·  Shift Run  ·  Ctrl Crouch  ·  F Flashlight  ·  F11 Fullscreen\nE / Left Click Interact  ·  Right Click / Space Hold breath (in a locker)",
	"end.win.sub": "The doors of Saint Halvard closed behind you.\nBut your sibling is still in there somewhere...",
	"end.lose.sub": "The Nurse never loses a patient.",
	"menu.help": "You entered the abandoned Saint Halvard looking for your sibling, and the door locked behind you.\nFind five fuses, start the basement generator and escape through the main door.\n\nWASD  Move          Shift  Run          Ctrl / C  Crouch\nF  Flashlight          E / Left Click  Interact          ESC  Pause\nRight Click / Space  Hold breath in a locker          F11  Fullscreen\n\nThe Nurse cannot see, but she hears everything and is drawn to light.\nRunning and opening doors make noise. Crouch-walking is silent.",
	"note.n1.title": "Reception — Notice",
	"note.n1.body": "SAINT HALVARD ASYLUM\nBoard Decision — 14 October 1987\n\nFollowing the \"incident\" in the basement, this hospital is closed indefinitely. All patients have been transferred.\n\nMains power has been cut. The main door is electronically locked and can only be opened by running the backup generator in the basement.\n\nComplaints from night-shift staff will not be considered.\nRumours about Nurse A. are unfounded.",
	"note.n2.title": "Patient Diary — Room 3",
	"note.n2.body": "She came again tonight. Heavy footsteps, like someone walking barefoot. Her eyes are bound, but she finds us.\n\nShe can't see. She HEARS.\n\nShe finds the ones who run. She finds the ones who scream.\n\nThomas shone his flashlight at her. She walked toward the light as if it called her. I never saw Thomas again.\n\nWalk slowly. Crouch. Never shine your light in her face.",
	"note.n3.title": "Shift Log",
	"note.n3.body": "03:02 — Patient 112 is not in his bed. The door was locked from the inside.\n03:40 — That smell in the corridor again. Wet soil and rust.\n04:15 — Found Agnes's old cap in my locker. Agnes has been dead for eight years.\n04:16 — Someone is humming in the corridor. A lullaby.\n\nDr. Voss pulled the generator fuses and hid them all over the building. \"If the power comes back, so does she,\" he said.",
	"note.n4.title": "Note Pinned to the Wall",
	"note.n4.body": "If you're reading this, listen to me:\n\nHide in the lockers. If she gets close, HOLD YOUR BREATH (right click). You can't hold it for long; if you run out, she'll hear you.\n\nIf she sees you hide, it's useless. Break her line of sight FIRST, then hide.\n\nRunning makes noise. Doors make noise. If you crouch-walk, she won't hear you.",
	"note.n5.title": "Surgical Report — Project SILENCE",
	"note.n5.body": "Dr. H. Voss — CONFIDENTIAL\n\nSubject: Agnes Marlow, head nurse.\nProcedure: Severing of the optic nerves, removal of the vocal cords.\n\nGoal: \"Pure attention\" under sensory deprivation. After surgery the subject walked for 41 hours without stopping. She did not eat. She did not sleep.\n\nHer hearing far exceeds expectations. She can hear a heartbeat at the other end of the corridor.\n\nNote: The subject is NOT under control.",
	"note.n6.title": "Morgue Record",
	"note.n6.body": "Record no: 1979/114\nName: Agnes Marlow\nCause of death: Unspecified\n\nBody placed in drawer number 3.\n\n— Addendum, two days later: Drawer found empty. Scratch marks on the inside.\n— Addendum, 1987: The drawer is empty again. Again.",
	"note.n7.title": "Dr. Voss's Letter",
	"note.n7.body": "To the Board,\n\nI removed the generator's five fuses and scattered them throughout the building. I had no other choice.\n\nWhen the power returns, the alarms will sound. When she hears them she will wake and come to the source of the noise. This building must stay dark. SHE must stay in the dark.\n\nI am leaving the basement key here. May God let no one use it.\n\n— H. Voss",
	"note.n8.title": "A Crumpled Letter",
	"note.n8.body": "If you found this, you came looking for me. You shouldn't have.\n\nIf you start the generator, the main door opens, but she will hear it too. Once the fuses are in, don't stop. Don't look back. RUN.\n\nI couldn't do it. My legs don't obey me anymore. The lullaby never ends.\n\nI love you. Get out.",
}

const TR := {
	"hud.controls": "\nWASD Hareket  ·  Shift Koş  ·  Ctrl Eğil  ·  F Fener  ·  F11 Tam ekran\nE / Sol Tık Etkileşim  ·  Sağ Tık / Boşluk Nefesini tut (dolapta)",
	"end.win.sub": "Saint Halvard'ın kapıları arkandan kapandı.\nAma kardeşin hâlâ orada bir yerde...",
	"end.lose.sub": "Hemşire hiçbir hastasını kaçırmaz.",
	"menu.help": "Kardeşini aramak için kapanmış Saint Halvard'a girdin; kapı arkandan kilitlendi.\nBeş sigortayı bul, bodrumdaki jeneratörü çalıştır ve ana kapıdan kaç.\n\nWASD  Hareket          Shift  Koş          Ctrl / C  Eğil\nF  Fener          E / Sol Tık  Etkileşim          ESC  Duraklat\nSağ Tık / Boşluk  Dolapta nefesini tut          F11  Tam ekran\n\nHemşire göremez ama çok iyi duyar ve ışığa yönelir.\nKoşmak ve kapı açmak ses çıkarır. Eğilerek yürümek sessizdir.",
	"note.n1.title": "Resepsiyon — Duyuru",
	"note.n1.body": "SAINT HALVARD AKIL HASTANESİ\nYönetim Kurulu Kararı — 14 Ekim 1987\n\nHastanemiz, bodrum katındaki \"olay\" sonrası süresiz olarak kapatılmıştır. Tüm hastalar sevk edilmiştir.\n\nŞebeke elektriği kesilmiştir. Ana kapı elektronik kilitlidir ve yalnızca bodrumdaki yedek jeneratör çalıştırılarak açılabilir.\n\nGece vardiyası personelinin şikâyetleri dikkate alınmayacaktır.\nHemşire A. hakkındaki söylentiler asılsızdır.",
	"note.n2.title": "Hasta Günlüğü — Oda 3",
	"note.n2.body": "Gece yine geldi. Ayak sesleri ağır, çıplak ayakla yürüyen biri gibi. Gözleri bağlı ama bizi buluyor.\n\nGörmüyor. DUYUYOR.\n\nKoşanları buluyor. Bağıranları buluyor.\n\nThomas fenerini ona tuttu. Işığa doğru yürüdü, sanki çağrılmış gibi. Thomas'ı bir daha görmedim.\n\nYavaş yürü. Eğil. Işığını onun yüzüne tutma.",
	"note.n3.title": "Vardiya Defteri",
	"note.n3.body": "03.02 — 112 numaralı hasta yatağında yok. Kapı içeriden kilitliydi.\n03.40 — Koridorda yine o koku. Islak toprak ve pas.\n04.15 — Agnes'in eski bonesini dolabımda buldum. Agnes öleli sekiz yıl oldu.\n04.16 — Biri koridorda mırıldanıyor. Bir ninni.\n\nDr. Voss jeneratörün sigortalarını söküp binanın dört bir yanına sakladı. \"Elektrik gelirse O da gelir\" dedi.",
	"note.n4.title": "Duvara İğnelenmiş Not",
	"note.n4.body": "Bunu okuyorsan beni dinle:\n\nDolaplara saklan. O yaklaşırsa NEFESİNİ TUT (sağ tık). Uzun tutamazsın; nefesin biterse duyar.\n\nSaklandığını görürse işe yaramaz. Önce gözden kaybol, SONRA saklan.\n\nKoşmak gürültü yapar. Kapılar gürültü yapar. Eğilerek yürürsen seni duymaz.",
	"note.n5.title": "Ameliyat Raporu — Proje SESSİZLİK",
	"note.n5.body": "Dr. H. Voss — GİZLİ\n\nDenek: Agnes Marlow, başhemşire.\nİşlem: Görme sinirlerinin kesilmesi, ses tellerinin alınması.\n\nAmaç: Uyaran yoksunluğu altında \"saf dikkat\". Denek ameliyattan sonra 41 saat kesintisiz yürüdü. Yemek yemedi. Uyumadı.\n\nİşitme duyusu beklenenin çok üzerinde. Koridorun öbür ucundaki bir kalp atışını duyabiliyor.\n\nNot: Denek kontrol altında DEĞİL.",
	"note.n6.title": "Morg Kaydı",
	"note.n6.body": "Kayıt no: 1979/114\nAd: Agnes Marlow\nÖlüm nedeni: Belirtilmemiş\n\nCeset 3 numaralı çekmeceye yerleştirildi.\n\n— Ek, iki gün sonra: Çekmece boş bulundu. İçeride tırnak izleri var.\n— Ek, 1987: Çekmece yine boş. Yine.",
	"note.n7.title": "Dr. Voss'un Mektubu",
	"note.n7.body": "Kurula,\n\nJeneratörün beş sigortasını söktüm ve binanın dört bir yanına dağıttım. Başka çarem yoktu.\n\nElektrik geldiğinde alarmlar çalar. Alarmı duyduğunda uyanır ve sesin kaynağına gelir. Bu bina karanlıkta kalmalı. O, karanlıkta kalmalı.\n\nBodrum anahtarını burada bırakıyorum. Tanrı kimsenin onu kullanmasına izin vermesin.\n\n— H. Voss",
	"note.n8.title": "Buruşuk Bir Mektup",
	"note.n8.body": "Bunu bulduysan demek ki beni aramaya geldin. Gelmemeliydin.\n\nJeneratörü çalıştırırsan ana kapı açılır ama O da duyar. Sigortaları taktıktan sonra durma. Arkana bakma. KOŞ.\n\nBen yapamadım. Bacaklarım artık beni dinlemiyor. Ninni hiç bitmiyor.\n\nSeni seviyorum. Kaç.",
}

static var _done := false


static func setup() -> void:
	if _done:
		return
	_done = true
	# Türkçe tabloda, İngilizce tablodaki her kısa anahtarın kendisini döndüren bir kayıt olmalı.
	# Aksi halde Godot eksik anahtarı yedek dil olan İngilizceye çevirir.
	var tr_full := TR.duplicate()
	for k in EN:
		if not tr_full.has(k):
			tr_full[k] = k
	TranslationServer.add_translation(_make("en", EN))
	TranslationServer.add_translation(_make("tr", tr_full))


static func _make(locale: String, messages: Dictionary) -> Translation:
	var t := Translation.new()
	t.locale = locale
	for k in messages:
		t.add_message(k, messages[k])
	return t
