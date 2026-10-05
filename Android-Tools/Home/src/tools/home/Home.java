package tools.home;

import android.app.Activity;
import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.ActivityInfo;
import android.content.pm.PackageManager;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.drawable.GradientDrawable;
import android.os.Bundle;
import android.text.TextUtils;
import android.util.TypedValue;
import android.view.Gravity;
import android.view.View;
import android.widget.GridLayout;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

import java.io.BufferedReader;
import java.io.IOException;
import java.io.InputStreamReader;
import java.util.ArrayList;
import java.util.List;

// Home screen showing the apps listed in assets/layout.txt (Layout.txt in the repo):
// one large "featured" tile, then a grid of apps.
@SuppressWarnings("deprecation") // onBackPressed, bar colors: still the simplest way on Android 13
public class Home extends Activity {
    private final List<String[]> entries = new ArrayList<>(); // {kind, package}

    // Redraw when apps are installed, removed, enabled or disabled
    private final BroadcastReceiver packagesChanged = new BroadcastReceiver() {
        @Override
        public void onReceive(Context context, Intent intent) {
            render();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        // Show the wallpaper behind the status and navigation bars
        getWindow().setStatusBarColor(Color.TRANSPARENT);
        getWindow().setNavigationBarColor(Color.TRANSPARENT);
        readLayout();
        IntentFilter filter = new IntentFilter();
        filter.addAction(Intent.ACTION_PACKAGE_ADDED);
        filter.addAction(Intent.ACTION_PACKAGE_REMOVED);
        filter.addAction(Intent.ACTION_PACKAGE_CHANGED);
        filter.addDataScheme("package");
        registerReceiver(packagesChanged, filter);
    }

    @Override
    protected void onDestroy() {
        unregisterReceiver(packagesChanged);
        super.onDestroy();
    }

    @Override
    protected void onResume() {
        super.onResume();
        render();
    }

    @Override
    public void onConfigurationChanged(Configuration newConfig) {
        super.onConfigurationChanged(newConfig);
        render();
    }

    @Override
    public void onBackPressed() {
        // Already home
    }

    private void readLayout() {
        try (BufferedReader reader = new BufferedReader(
                new InputStreamReader(getAssets().open("layout.txt")))) {
            String line;
            while ((line = reader.readLine()) != null) {
                String[] fields = line.replaceAll("#.*", "").trim().split("\\s+");
                if (fields.length == 2) {
                    entries.add(fields);
                }
            }
        } catch (IOException e) {
            // No layout: empty home screen
        }
    }

    private void render() {
        PackageManager pm = getPackageManager();
        int columns = Math.max(3, getResources().getConfiguration().screenWidthDp / 100);

        LinearLayout content = new LinearLayout(this);
        content.setOrientation(LinearLayout.VERTICAL);
        content.setPadding(dp(16), dp(24), dp(16), dp(16));

        GridLayout grid = new GridLayout(this);
        grid.setColumnCount(columns);

        for (String[] entry : entries) {
            Intent launch = pm.getLaunchIntentForPackage(entry[1]);
            if (launch == null) {
                continue; // Not installed or disabled
            }
            ActivityInfo info = pm.resolveActivity(launch, 0).activityInfo;
            if (entry[0].equals("featured")) {
                content.addView(featuredTile(info, launch));
            } else if (entry[0].equals("app")) {
                GridLayout.LayoutParams params = new GridLayout.LayoutParams(
                        GridLayout.spec(GridLayout.UNDEFINED),
                        GridLayout.spec(GridLayout.UNDEFINED, 1f));
                params.width = 0;
                grid.addView(appCell(info, launch), params);
            }
        }
        content.addView(grid);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(content);
        setContentView(scroll);
    }

    private View featuredTile(ActivityInfo info, Intent launch) {
        LinearLayout tile = new LinearLayout(this);
        tile.setOrientation(LinearLayout.VERTICAL);
        tile.setGravity(Gravity.CENTER);
        tile.setPadding(dp(16), dp(24), dp(16), dp(20));
        GradientDrawable background = new GradientDrawable();
        background.setColor(Color.argb(230, 255, 255, 255));
        background.setCornerRadius(dp(24));
        tile.setBackground(background);
        tile.setOnClickListener(v -> startActivity(launch));

        ImageView icon = new ImageView(this);
        icon.setImageDrawable(info.loadIcon(getPackageManager()));
        tile.addView(icon, new LinearLayout.LayoutParams(dp(128), dp(128)));

        TextView label = new TextView(this);
        label.setText(info.loadLabel(getPackageManager()));
        label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 28);
        label.setTextColor(Color.rgb(32, 33, 36));
        label.setGravity(Gravity.CENTER);
        label.setPadding(0, dp(12), 0, 0);
        tile.addView(label);

        LinearLayout.LayoutParams params = new LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT);
        params.bottomMargin = dp(24);
        tile.setLayoutParams(params);
        return tile;
    }

    private View appCell(ActivityInfo info, Intent launch) {
        LinearLayout cell = new LinearLayout(this);
        cell.setOrientation(LinearLayout.VERTICAL);
        cell.setGravity(Gravity.CENTER_HORIZONTAL);
        cell.setPadding(dp(4), dp(12), dp(4), dp(12));
        cell.setOnClickListener(v -> startActivity(launch));

        ImageView icon = new ImageView(this);
        icon.setImageDrawable(info.loadIcon(getPackageManager()));
        cell.addView(icon, new LinearLayout.LayoutParams(dp(56), dp(56)));

        TextView label = new TextView(this);
        label.setText(info.loadLabel(getPackageManager()));
        label.setTextSize(TypedValue.COMPLEX_UNIT_SP, 13);
        label.setTextColor(Color.WHITE);
        label.setShadowLayer(dp(3), 0, dp(1), Color.argb(200, 0, 0, 0));
        label.setGravity(Gravity.CENTER);
        label.setSingleLine();
        label.setEllipsize(TextUtils.TruncateAt.END);
        label.setPadding(0, dp(6), 0, 0);
        cell.addView(label);
        return cell;
    }

    private int dp(int value) {
        return Math.round(value * getResources().getDisplayMetrics().density);
    }
}
