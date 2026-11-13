package ir.hazrat.hesab_hazrat

import android.content.Intent
import com.google.android.gms.auth.api.identity.AuthorizationRequest
import com.google.android.gms.auth.api.identity.ClearTokenRequest
import com.google.android.gms.auth.api.identity.Identity
import com.google.android.gms.common.api.Scope
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.net.HttpURLConnection
import java.net.URL
import java.net.URLEncoder

/** Tokens stay in Play Services and transient memory, never the finance document. */
class MainActivity : FlutterActivity() {
    private var pending: MethodChannel.Result? = null
    private val scopes = listOf(Scope("https://www.googleapis.com/auth/spreadsheets"))
    private val requestCode = 8731
    private var lastToken: String? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "ir.hazrat.hesab_hazrat/google")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "authorize" -> authorize(call.argument<Boolean>("interactive") == true, result)
                    "signOut" -> disconnect(result)
                    else -> result.notImplemented()
                }
            }
    }

    private fun authorize(interactive: Boolean, result: MethodChannel.Result) {
        if (pending != null) { result.error("BUSY", "یک درخواست گوگل در حال اجرا است.", null); return }
        val request = AuthorizationRequest.builder().setRequestedScopes(scopes).build()
        Identity.getAuthorizationClient(this).authorize(request)
            .addOnSuccessListener { authorization ->
                if (authorization.hasResolution()) {
                    if (!interactive) { result.error("SIGN_IN_REQUIRED", "حساب گوگل را از تنظیمات متصل کنید.", null); return@addOnSuccessListener }
                    pending = result
                    try {
                        startIntentSenderForResult(authorization.pendingIntent!!.intentSender, requestCode, null, 0, 0, 0)
                    } catch (e: Exception) { pending = null; result.error("GOOGLE_AUTH", e.localizedMessage, null) }
                } else {
                    lastToken = authorization.accessToken
                    result.success(lastToken)
                }
            }
            .addOnFailureListener { e -> result.error("GOOGLE_AUTH", e.localizedMessage, null) }
    }

    @Deprecated("Required by FlutterActivity activity result forwarding")
    override fun onActivityResult(requestCode: Int, resultCode: Int, data: Intent?) {
        super.onActivityResult(requestCode, resultCode, data)
        if (requestCode != this.requestCode) return
        val result = pending ?: return
        pending = null
        try {
            val authorization = Identity.getAuthorizationClient(this).getAuthorizationResultFromIntent(data)
            lastToken = authorization.accessToken
            result.success(lastToken)
        } catch (e: Exception) { result.error("GOOGLE_AUTH", "ورود لغو شد یا مجوز داده نشد. ${e.localizedMessage}", null) }
    }

    private fun disconnect(result: MethodChannel.Result) {
        val request = AuthorizationRequest.builder().setRequestedScopes(scopes).build()
        Identity.getAuthorizationClient(this).authorize(request).addOnSuccessListener { auth ->
            val token = auth.accessToken ?: lastToken
            if (token == null) { result.success(null); return@addOnSuccessListener }
            Thread {
                try {
                    val connection = URL("https://oauth2.googleapis.com/revoke").openConnection() as HttpURLConnection
                    connection.requestMethod = "POST"
                    connection.connectTimeout = 15000
                    connection.readTimeout = 15000
                    connection.doOutput = true
                    connection.setRequestProperty("Content-Type", "application/x-www-form-urlencoded")
                    connection.outputStream.use { it.write("token=${URLEncoder.encode(token, "UTF-8")}".toByteArray()) }
                    val code = connection.responseCode
                    connection.disconnect()
                    if (code != 200) throw IllegalStateException("لغو مجوز به اینترنت نیاز دارد ($code)")
                    runOnUiThread {
                        Identity.getAuthorizationClient(this).clearToken(ClearTokenRequest.builder().setToken(token).build())
                        lastToken = null
                        result.success(null)
                    }
                } catch (e: Exception) { runOnUiThread { result.error("DISCONNECT", e.localizedMessage, null) } }
            }.start()
        }.addOnFailureListener { e -> result.error("DISCONNECT", e.localizedMessage, null) }
    }
}
