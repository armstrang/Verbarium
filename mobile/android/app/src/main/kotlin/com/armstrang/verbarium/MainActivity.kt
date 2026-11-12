package com.armstrang.verbarium

import android.app.Activity
import android.content.ActivityNotFoundException
import android.content.Intent
import android.media.AudioAttributes
import android.media.MediaPlayer
import android.media.SoundPool
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import androidx.core.splashscreen.SplashScreen.Companion.installSplashScreen
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import org.json.JSONArray

/**
 * The Android side of Verbarium, on the method channel "verbarium/native": the app's files folder, the system
 * splash hand-over, and sound (a looping court ambience through MediaPlayer, short effects through SoundPool).
 * The sounds are plain resources in res/raw, made by content/tools/make_music.py from CC0 samples.
 */
class MainActivity : FlutterActivity() {
    private val main = Handler(Looper.getMainLooper())
    private var donate: Donate? = null

    /** Google Play Billing only starts when the support page is opened, and ends when it is left: the internet
     *  permission that Billing brings is used for nothing else */
    private fun don(): Donate = donate ?: Donate(this).also { donate = it }

    /** installed from the Play Store? Read on the phone, no network */
    private fun fromPlay(): Boolean = try {
        val who = if (Build.VERSION.SDK_INT >= 30) packageManager.getInstallSourceInfo(packageName).installingPackageName
        else @Suppress("DEPRECATION") packageManager.getInstallerPackageName(packageName)
        who == "com.android.vending"
    } catch (e: Exception) {
        false
    }
    // Cadangan: the system's file picker, answered in onActivityResult
    private var saveText: String? = null
    private var saveResult: MethodChannel.Result? = null
    private var openResult: MethodChannel.Result? = null

    @Volatile private var ready = false
    private var startedAt = 0L

    private var music: MediaPlayer? = null
    private var musicTrack = ""
    private var wantedTrack = "m0"
    private var musicWanted = false
    private var musicVolume = 0.5f
    private var pool: SoundPool? = null
    private val loaded = HashMap<String, Int>()

    // direct references, so the resource shrinker keeps every sound
    private val effects = mapOf(
        "quill" to R.raw.quill,
        "seal" to R.raw.seal,
        "wrong" to R.raw.wrong,
        "page" to R.raw.page,
        "tap" to R.raw.tap,
        "rise" to R.raw.rise,
        "fanfare" to R.raw.fanfare,
        "hit" to R.raw.hit,
        "crit" to R.raw.crit,
        "hurt" to R.raw.hurt,
        "levelup" to R.raw.levelup,
        "victory" to R.raw.victory,
        "defeat" to R.raw.defeat,
        "tap_p" to R.raw.tap_p,
        "tap_0" to R.raw.tap_0,
        "tap_1" to R.raw.tap_1,
        "tap_2" to R.raw.tap_2,
        "tap_3" to R.raw.tap_3,
        "hit_p" to R.raw.hit_p,
        "hit_0" to R.raw.hit_0,
        "hit_1" to R.raw.hit_1,
        "hit_2" to R.raw.hit_2,
        "hit_3" to R.raw.hit_3,
        "hitx_0" to R.raw.hitx_0,
        "hitx_1" to R.raw.hitx_1,
        "hitx_2" to R.raw.hitx_2,
        "hitx_3" to R.raw.hitx_3,
        // the kingdoms' arms coming alive (ui/crest.dart)
        "crest_en" to R.raw.crest_en,
        "crest_de" to R.raw.crest_de,
        "crest_es" to R.raw.crest_es,
        "crest_fr" to R.raw.crest_fr,
        "crest_pt" to R.raw.crest_pt,
    )

    // one tune per title, and one for fights
    private val tracks = mapOf(
        "m0" to R.raw.m0,
        "m1" to R.raw.m1,
        "m2" to R.raw.m2,
        "m3" to R.raw.m3,
        "m4" to R.raw.m4,
        "m5" to R.raw.m5,
        "m6" to R.raw.m6,
        "battle" to R.raw.battle,
    )

    override fun onCreate(savedInstanceState: Bundle?) {
        startedAt = SystemClock.uptimeMillis()
        installSplashScreen().apply {
            setKeepOnScreenCondition { !ready && SystemClock.uptimeMillis() - startedAt < 2500 }
            setOnExitAnimationListener { v ->
                v.view.animate().alpha(0f).setDuration(150).withEndAction { v.remove() }.start()
            }
        }
        super.onCreate(savedInstanceState)
        startPool()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "verbarium/native").setMethodCallHandler { call, result ->
            when (call.method) {
                "filesDir" -> result.success(filesDir.absolutePath)
                "ready" -> { ready = true; result.success(null) }
                "sfx" -> {
                    val name = call.argument<String>("name") ?: ""
                    val vol = (call.argument<Double>("volume") ?: 1.0).toFloat().coerceIn(0f, 1f)
                    val id = loaded[name]
                    if (id != null) pool?.play(id, vol, vol, 1, 0, 1f)
                    result.success(null)
                }
                "music" -> {
                    musicWanted = call.argument<Boolean>("on") ?: false
                    musicVolume = (call.argument<Double>("volume") ?: 0.5).toFloat().coerceIn(0f, 1f)
                    wantedTrack = call.argument<String>("track") ?: "m0"
                    applyMusic()
                    result.success(null)
                }
                "openUrl" -> {
                    try {
                        startActivity(Intent(Intent.ACTION_VIEW, Uri.parse(call.arguments as String)))
                    } catch (_: ActivityNotFoundException) {
                    }
                    result.success(null)
                }
                "donProducts" -> {
                    val a = JSONArray(call.arguments as String)
                    don().products((0 until a.length()).map { a.getString(it) }) { main.post { result.success(it) } }
                }
                "donBuy" -> don().buy(call.arguments as String) { main.post { result.success(it) } }
                "donEnd" -> {
                    donate?.end()
                    donate = null
                    result.success(null)
                }
                "fromPlay" -> result.success(fromPlay())
                "backupSave" -> {
                    saveResult?.success("cancel")
                    saveText = call.argument<String>("text") ?: ""
                    saveResult = result
                    val i = Intent(Intent.ACTION_CREATE_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("application/json")
                        .putExtra(Intent.EXTRA_TITLE, call.argument<String>("name") ?: "verbarium.json")
                    try {
                        startActivityForResult(i, REQ_SAVE)
                    } catch (_: ActivityNotFoundException) {
                        saveResult = null
                        result.success("error")
                    }
                }
                "backupOpen" -> {
                    openResult?.success(null)
                    openResult = result
                    val i = Intent(Intent.ACTION_OPEN_DOCUMENT)
                        .addCategory(Intent.CATEGORY_OPENABLE)
                        .setType("*/*")
                    try {
                        startActivityForResult(i, REQ_OPEN)
                    } catch (_: ActivityNotFoundException) {
                        openResult = null
                        result.success(null)
                    }
                }
                else -> result.notImplemented()
            }
        }
    }

    @Deprecated("startActivityForResult is enough here: two plain requests, no fragments")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        val uri = data?.data
        when (requestCode) {
            REQ_SAVE -> {
                val r = saveResult ?: return
                saveResult = null
                val text = saveText ?: ""
                saveText = null
                if (resultCode != Activity.RESULT_OK || uri == null) return r.success("cancel")
                try {
                    contentResolver.openOutputStream(uri, "wt")?.use { it.write(text.toByteArray(Charsets.UTF_8)) }
                        ?: return r.success("error")
                    r.success("ok")
                } catch (e: Exception) {
                    r.success("error")
                }
            }
            REQ_OPEN -> {
                val r = openResult ?: return
                openResult = null
                if (resultCode != Activity.RESULT_OK || uri == null) return r.success(null)
                try {
                    val text = contentResolver.openInputStream(uri)?.use { s ->
                        val bytes = s.readBytes()
                        if (bytes.size > MAX_BACKUP) null else String(bytes, Charsets.UTF_8)
                    }
                    r.success(text)
                } catch (e: Exception) {
                    r.success(null)
                }
            }
        }
    }

    private fun startPool() {
        val attrs = AudioAttributes.Builder()
            .setUsage(AudioAttributes.USAGE_GAME)
            .setContentType(AudioAttributes.CONTENT_TYPE_SONIFICATION)
            .build()
        val p = SoundPool.Builder().setMaxStreams(6).setAudioAttributes(attrs).build()
        for ((name, res) in effects) loaded[name] = p.load(this, res, 1)
        pool = p
    }

    private fun applyMusic() {
        if (!musicWanted) {
            music?.let { if (it.isPlaying) it.pause() }
            return
        }
        var m = music
        if (m == null || musicTrack != wantedTrack) {
            m?.release()
            music = null
            val res = tracks[wantedTrack] ?: R.raw.m0
            m = MediaPlayer.create(this, res) ?: return
            m.isLooping = true
            music = m
            musicTrack = wantedTrack
        }
        m.setVolume(musicVolume, musicVolume)
        if (!m.isPlaying) m.start()
    }

    override fun onPause() {
        super.onPause()
        music?.let { if (it.isPlaying) it.pause() }
    }

    override fun onResume() {
        super.onResume()
        if (musicWanted) applyMusic()
    }

    override fun onDestroy() {
        donate?.end()
        donate = null
        music?.release()
        music = null
        pool?.release()
        pool = null
        super.onDestroy()
    }

    companion object {
        private const val REQ_SAVE = 4101
        private const val REQ_OPEN = 4102
        private const val MAX_BACKUP = 32 * 1024 * 1024
    }
}
