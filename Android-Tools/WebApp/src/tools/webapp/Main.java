package tools.webapp;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;
import android.webkit.CookieManager;
import android.webkit.ValueCallback;
import android.webkit.WebChromeClient;
import android.webkit.WebResourceRequest;
import android.webkit.WebSettings;
import android.webkit.WebView;
import android.webkit.WebViewClient;

// Shows the site from the manifest's "url" meta-data full screen in a WebView. Pages on the
// same host stay in the app; other links open in the default browser.
@SuppressWarnings("deprecation") // onBackPressed, startActivityForResult: simplest on Android 7-15
public class Main extends Activity {
    private static final int PICK_FILE = 1;

    private WebView web;
    private String host;
    private ValueCallback<Uri[]> pendingUpload;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        String url;
        try {
            url = getPackageManager()
                    .getActivityInfo(getComponentName(), PackageManager.GET_META_DATA)
                    .metaData.getString("url");
        } catch (PackageManager.NameNotFoundException e) {
            throw new IllegalStateException(e); // Unreachable: this activity is in its own package
        }
        host = Uri.parse(url).getHost();

        web = new WebView(this);
        WebSettings settings = web.getSettings();
        settings.setJavaScriptEnabled(true);
        settings.setDomStorageEnabled(true);
        settings.setDatabaseEnabled(true);
        CookieManager.getInstance().setAcceptCookie(true);

        web.setWebViewClient(new WebViewClient() {
            @Override
            public boolean shouldOverrideUrlLoading(WebView view, WebResourceRequest request) {
                Uri uri = request.getUrl();
                if (host.equals(uri.getHost())) {
                    return false;
                }
                openExternally(uri);
                return true;
            }
        });
        web.setWebChromeClient(new WebChromeClient() {
            @Override
            public boolean onShowFileChooser(WebView view, ValueCallback<Uri[]> callback,
                    FileChooserParams params) {
                if (pendingUpload != null) {
                    pendingUpload.onReceiveValue(null);
                }
                pendingUpload = callback;
                try {
                    startActivityForResult(params.createIntent(), PICK_FILE);
                } catch (ActivityNotFoundException e) {
                    pendingUpload = null;
                    return false;
                }
                return true;
            }
        });
        web.setDownloadListener((downloadUrl, userAgent, disposition, mimeType, length) ->
                openExternally(Uri.parse(downloadUrl)));

        setContentView(web);
        if (savedInstanceState != null) {
            web.restoreState(savedInstanceState);
        } else {
            web.loadUrl(url);
        }
    }

    private void openExternally(Uri uri) {
        try {
            startActivity(new Intent(Intent.ACTION_VIEW, uri));
        } catch (ActivityNotFoundException e) {
            // Nothing can open it
        }
    }

    @Override
    protected void onActivityResult(int requestCode, int resultCode, Intent data) {
        if (requestCode == PICK_FILE && pendingUpload != null) {
            pendingUpload.onReceiveValue(WebChromeClient.FileChooserParams.parseResult(resultCode, data));
            pendingUpload = null;
        }
    }

    @Override
    protected void onSaveInstanceState(Bundle outState) {
        super.onSaveInstanceState(outState);
        web.saveState(outState);
    }

    @Override
    protected void onPause() {
        super.onPause();
        CookieManager.getInstance().flush(); // Keep the login across restarts
    }

    @Override
    public void onBackPressed() {
        if (web.canGoBack()) {
            web.goBack();
        } else {
            super.onBackPressed();
        }
    }

    @Override
    protected void onDestroy() {
        web.destroy();
        super.onDestroy();
    }
}
