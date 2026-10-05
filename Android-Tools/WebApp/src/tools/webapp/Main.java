package tools.webapp;

import android.app.Activity;
import android.content.ActivityNotFoundException;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Bundle;

// Opens the URL from the manifest's "url" meta-data in Chrome, then closes.
public class Main extends Activity {
    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        try {
            String url = getPackageManager()
                    .getActivityInfo(getComponentName(), PackageManager.GET_META_DATA)
                    .metaData.getString("url");
            Intent intent = new Intent(Intent.ACTION_VIEW, Uri.parse(url));
            // Chrome reuses a single tab per application id instead of opening a new one each time
            intent.putExtra("com.android.browser.application_id", getPackageName());
            intent.setPackage("com.android.chrome");
            try {
                startActivity(intent);
            } catch (ActivityNotFoundException e) {
                startActivity(intent.setPackage(null));
            }
        } catch (PackageManager.NameNotFoundException e) {
            // Unreachable: this activity is always in its own package
        }
        finish();
    }
}
