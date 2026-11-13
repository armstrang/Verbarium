package com.armstrang.verbarium

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.os.Handler
import android.os.Looper
import android.text.SpannableStringBuilder
import android.text.Spanned
import android.text.style.ForegroundColorSpan
import android.text.style.StyleSpan
import android.text.style.UnderlineSpan
import android.widget.RemoteViews
import org.json.JSONObject
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * The practice widget on the home screen: one sentence with a gap and four words to choose from, no typing.
 * The app writes today's questions to files/widget/deck.json (lib/app/home_widget.dart); each answer here is added
 * to files/widget/answers.jsonl and counted by the app when it next opens (light for memory, 1–5 XP, ten a day keep
 * the streak). The questions come round again until the app writes new ones. Nothing here touches the network.
 */
class PracticeWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        for (id in ids) manager.updateAppWidget(id, views(context, null))
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ANSWER) {
            val pick = intent.getIntExtra(PICK, -1)
            val done = goAsync()
            val shown = answer(context, pick)
            if (shown == null) {
                redraw(context, null)
                done.finish()
                return
            }
            redraw(context, shown)
            // the answer stays a moment, then the next question
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    next(context)
                    redraw(context, null)
                } finally {
                    done.finish()
                }
            }, if (shown.ok) 1300L else 2400L)
            return
        }
        super.onReceive(context, intent)
    }

    /** an answer being shown: which option was chosen and whether it was right */
    private class Shown(val pick: Int, val ok: Boolean, val reached: Boolean)

    companion object {
        private const val ANSWER = "com.armstrang.verbarium.WIDGET_ANSWER"
        private const val PICK = "pick"
        private const val PREFS = "practice_widget"
        private const val STREAK = 10
        private val OPTS = intArrayOf(R.id.w_o0, R.id.w_o1, R.id.w_o2, R.id.w_o3)

        /** the app wrote new questions: draw them */
        fun refresh(context: Context) {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val deck = deck(context)
            // new questions of another day or kingdom start from the first
            val key = deck?.let { it.optString("day") + "/" + it.optString("k") } ?: ""
            if (p.getString("deck", "") != key) p.edit().putString("deck", key).putInt("idx", 0).apply()
            redraw(context, null)
        }

        private fun today(): String = SimpleDateFormat("yyyyMMdd", Locale.US).format(Date())

        private fun deck(context: Context): JSONObject? = try {
            val f = File(context.filesDir, "widget/deck.json")
            if (f.exists()) JSONObject(f.readText()) else null
        } catch (e: Exception) {
            null
        }

        /** answers given in the widget today (reset each day) */
        private fun count(context: Context): Int {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            if (p.getString("day", "") != today()) p.edit().putString("day", today()).putInt("n", 0).apply()
            return p.getInt("n", 0)
        }

        private fun redraw(context: Context, shown: Shown?) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, PracticeWidget::class.java))
            if (ids.isEmpty()) return
            val v = views(context, shown)
            for (id in ids) manager.updateAppWidget(id, v)
        }

        /** records the answer [pick] to the question on show; null when there is nothing to answer */
        private fun answer(context: Context, pick: Int): Shown? {
            val deck = deck(context) ?: return null
            val items = deck.optJSONArray("items") ?: return null
            if (items.length() == 0 || pick !in 0..3) return null
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            // one answer at a time; a hold left by a stopped process lapses after a few seconds
            if (System.currentTimeMillis() - p.getLong("busy", 0L) < 4000L) return null
            val item = items.getJSONObject(p.getInt("idx", 0) % items.length())
            val opts = item.getJSONArray("opt")
            val ok = opts.getString(pick) == item.getString("ans")
            val line = JSONObject()
                .put("k", deck.optString("k"))
                .put("id", item.getString("id"))
                .put("ok", ok)
                .put("t", System.currentTimeMillis())
            try {
                val dir = File(context.filesDir, "widget")
                dir.mkdirs()
                File(dir, "answers.jsonl").appendText(line.toString() + "\n")
            } catch (e: Exception) {
                return null
            }
            val n = count(context) + 1
            p.edit().putInt("n", n).putLong("busy", System.currentTimeMillis()).apply()
            return Shown(pick, ok, n == STREAK)
        }

        private fun next(context: Context) {
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            p.edit().putInt("idx", p.getInt("idx", 0) + 1).putLong("busy", 0L).apply()
        }

        private fun views(context: Context, shown: Shown?): RemoteViews {
            val v = RemoteViews(context.packageName, R.layout.practice_widget)
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            v.setOnClickPendingIntent(R.id.w_head, open)
            v.setOnClickPendingIntent(R.id.w_sentence, open)
            val deck = deck(context)
            val items = deck?.optJSONArray("items")
            if (deck == null || items == null || items.length() == 0) {
                v.setTextViewText(R.id.w_kingdom, "Verbarium")
                v.setTextViewText(R.id.w_count, "")
                v.setTextViewText(R.id.w_sentence, deck?.optJSONObject("say")?.optString("empty")
                    ?: context.getString(R.string.widget_empty))
                v.setTextViewText(R.id.w_note, "")
                for (o in OPTS) v.setViewVisibility(o, android.view.View.INVISIBLE)
                return v
            }
            val say = deck.optJSONObject("say") ?: JSONObject()
            val p = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val item = items.getJSONObject(p.getInt("idx", 0) % items.length())
            val ans = item.getString("ans")
            val opts = item.getJSONArray("opt")
            val n = count(context)
            v.setTextViewText(R.id.w_kingdom, deck.optString("name"))
            v.setTextViewText(R.id.w_count, "${minOf(n, STREAK)}/$STREAK ${say.optString("today")}")

            val ink = context.getColor(R.color.w_ink)
            val good = context.getColor(R.color.w_good)
            val bad = context.getColor(R.color.w_bad)
            val on = context.getColor(R.color.w_on)
            val muted = context.getColor(R.color.w_muted)

            // the sentence: the gap as one long line, or the word written in once answered
            val s = SpannableStringBuilder(item.optString("a"))
            if (s.isNotEmpty()) s.append(' ')
            val at = s.length
            if (shown == null) {
                s.append("     ")
                s.setSpan(UnderlineSpan(), at, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            } else {
                s.append(ans)
                s.setSpan(StyleSpan(Typeface.BOLD), at, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
                s.setSpan(ForegroundColorSpan(good), at, s.length, Spanned.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
            val after = item.optString("b")
            if (after.isNotEmpty() && !after.startsWith(".") && !after.startsWith(",") && !after.startsWith("?") &&
                !after.startsWith("!") && !after.startsWith(";") && !after.startsWith(":")) s.append(' ')
            s.append(after)
            v.setTextViewText(R.id.w_sentence, s)

            // below: the meaning from the start under B1, only the kind of word above; after answering, the meaning
            val mean = item.optString("mean")
            val pos = item.optString("pos")
            val note = when {
                shown == null -> if (item.optBoolean("show")) "$mean · $pos" else pos
                shown.reached -> say.optString("done")
                shown.ok -> "${say.optString("right")} · $mean"
                else -> "${say.optString("wrong")} $ans · $mean"
            }
            v.setTextViewText(R.id.w_note, note)
            v.setTextColor(R.id.w_note, when {
                shown == null -> muted
                shown.ok || shown.reached -> good
                else -> bad
            })

            for (i in 0..3) {
                val id = OPTS[i]
                val word = opts.optString(i)
                v.setViewVisibility(id, android.view.View.VISIBLE)
                v.setTextViewText(id, word)
                var bg = R.drawable.w_opt
                var fg = ink
                if (shown != null) {
                    if (word == ans && i == shown.pick) { bg = R.drawable.w_opt_right; fg = on }
                    else if (word == ans) { bg = R.drawable.w_opt_answer; fg = good }
                    else if (i == shown.pick) { bg = R.drawable.w_opt_wrong; fg = bad }
                }
                v.setInt(id, "setBackgroundResource", bg)
                v.setTextColor(id, fg)
                val tap = PendingIntent.getBroadcast(
                    context, 100 + i,
                    Intent(context, PracticeWidget::class.java).setAction(ANSWER).putExtra(PICK, i),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                )
                v.setOnClickPendingIntent(id, tap)
            }
            return v
        }
    }
}
