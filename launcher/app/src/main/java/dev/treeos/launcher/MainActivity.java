package dev.treeos.launcher;

import android.app.Activity;
import android.app.AlertDialog;
import android.content.Intent;
import android.content.IntentFilter;
import android.content.pm.PackageManager;
import android.content.pm.ResolveInfo;
import android.content.res.Configuration;
import android.graphics.Color;
import android.graphics.drawable.Drawable;
import android.net.Uri;
import android.os.BatteryManager;
import android.os.Bundle;
import android.os.Handler;
import android.provider.MediaStore;
import android.provider.Settings;
import android.text.Editable;
import android.text.TextUtils;
import android.text.TextWatcher;
import android.view.Gravity;
import android.view.View;
import android.view.ViewGroup;
import android.widget.BaseAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.GridView;
import android.widget.ImageView;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

import java.text.SimpleDateFormat;
import java.util.ArrayList;
import java.util.Collections;
import java.util.Comparator;
import java.util.Date;
import java.util.List;
import java.util.Locale;

public class MainActivity extends Activity {

    static class AppItem {
        String label;
        String pkg;
        String cls;
        Drawable icon;
    }

    private List<AppItem> allApps = new ArrayList<>();
    private List<AppItem> shownApps = new ArrayList<>();
    // App list (labels + icons) is expensive to build and identical across
    // activity recreations in the same process — cache it statically so a
    // rotation does not redo PackageManager queries and icon loads on the
    // main thread (that work could ANR on slow devices/emulators).
    private static List<AppItem> cachedApps;
    private AppAdapter adapter;
    private TextView clockView;
    private TextView dateView;
    private EditText searchBox;
    private Handler handler = new Handler();
    private Runnable tick = new Runnable() {
        @Override public void run() {
            updateClock();
            handler.postDelayed(this, 20000);
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        int green = Color.rgb(122, 199, 79);
        int dark = Color.rgb(11, 26, 16);
        int panel = Color.rgb(18, 38, 24);
        // Landscape has little vertical room: compact the header and widen the grid.
        boolean landscape = getResources().getConfiguration().orientation
                == Configuration.ORIENTATION_LANDSCAPE;

        LinearLayout root = new LinearLayout(this);
        root.setOrientation(LinearLayout.VERTICAL);
        root.setBackgroundColor(dark);
        root.setPadding(36, landscape ? 16 : 48, 36, 24);

        TextView brand = new TextView(this);
        brand.setText("🌳 TreeOS  •  0.4");
        brand.setTextColor(green);
        brand.setTextSize(16);
        brand.setGravity(Gravity.CENTER);
        root.addView(brand);

        clockView = new TextView(this);
        clockView.setTextColor(Color.WHITE);
        clockView.setTextSize(landscape ? 34 : 48);
        clockView.setGravity(Gravity.CENTER);
        root.addView(clockView);

        dateView = new TextView(this);
        dateView.setTextColor(Color.rgb(190, 220, 180));
        dateView.setTextSize(16);
        dateView.setGravity(Gravity.CENTER);
        root.addView(dateView);

        EditText search = new EditText(this);
        searchBox = search;
        // A stable id lets the framework save/restore the query text across
        // recreation (rotation); without one the typed query is lost.
        search.setId(1001);
        search.setHint("Search apps");
        search.setHintTextColor(Color.rgb(150, 170, 150));
        search.setTextColor(Color.WHITE);
        search.setSingleLine(true);
        search.setBackgroundColor(panel);
        search.setPadding(28, 20, 28, 20);
        LinearLayout.LayoutParams sp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        sp.setMargins(0, landscape ? 12 : 28, 0, 16);
        search.setLayoutParams(sp);
        root.addView(search);

        GridView grid = new GridView(this);
        grid.setNumColumns(landscape ? 6 : 4);
        grid.setVerticalSpacing(24);
        grid.setHorizontalSpacing(16);
        grid.setStretchMode(GridView.STRETCH_COLUMN_WIDTH);
        LinearLayout.LayoutParams gp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        grid.setLayoutParams(gp);
        adapter = new AppAdapter();
        grid.setAdapter(adapter);
        grid.setOnItemClickListener((parent, view, position, id) -> {
            AppItem item = shownApps.get(position);
            try {
                Intent i = new Intent(Intent.ACTION_MAIN);
                i.addCategory(Intent.CATEGORY_LAUNCHER);
                i.setClassName(item.pkg, item.cls);
                i.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                startActivity(i);
            } catch (Exception e) {
                Toast.makeText(this, "Can't open " + item.label, Toast.LENGTH_SHORT).show();
            }
        });
        grid.setOnItemLongClickListener((parent, view, position, id) -> {
            AppItem item = shownApps.get(position);
            try {
                Intent info = new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS);
                info.setData(Uri.parse("package:" + item.pkg));
                startActivity(info);
            } catch (Exception e) {
                Toast.makeText(this, item.label + " • " + item.pkg, Toast.LENGTH_LONG).show();
            }
            return true;
        });
        root.addView(grid);

        TextView empty = new TextView(this);
        empty.setText("No apps match");
        empty.setTextColor(Color.rgb(150, 170, 150));
        empty.setTextSize(16);
        empty.setGravity(Gravity.CENTER);
        empty.setVisibility(View.GONE);
        root.addView(empty);
        grid.setEmptyView(empty);

        // Dock
        LinearLayout dock = new LinearLayout(this);
        dock.setOrientation(LinearLayout.HORIZONTAL);
        dock.setGravity(Gravity.CENTER);
        dock.setBackgroundColor(panel);
        dock.setPadding(12, 12, 12, 12);
        dock.addView(dockBtn("📞\nPhone", v -> {
            try { startActivity(new Intent(Intent.ACTION_DIAL)); } catch (Exception ignored) {}
        }));
        dock.addView(dockBtn("💬\nTexts", v -> {
            try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("sms:"))); } catch (Exception ignored) {}
        }));
        dock.addView(dockBtn("🌐\nWeb", v -> {
            try { startActivity(new Intent(Intent.ACTION_VIEW, Uri.parse("https://example.com"))); } catch (Exception ignored) {}
        }));
        dock.addView(dockBtn("📷\nCam", v -> {
            try { startActivity(new Intent(MediaStore.INTENT_ACTION_STILL_IMAGE_CAMERA)); } catch (Exception ignored) {}
        }));
        dock.addView(dockBtn("🌳\nTree", v -> showTreePanel()));
        dock.addView(dockBtn("⚙️\nSetup", v -> {
            try { startActivity(new Intent(Settings.ACTION_SETTINGS)); } catch (Exception ignored) {}
        }));
        root.addView(dock);

        setContentView(root);

        loadApps();
        search.addTextChangedListener(new TextWatcher() {
            @Override public void beforeTextChanged(CharSequence s, int a, int b, int c) {}
            @Override public void onTextChanged(CharSequence s, int a, int b, int c) { filter(s.toString()); }
            @Override public void afterTextChanged(Editable s) {}
        });
        updateClock();
    }

    private Button dockBtn(String label, View.OnClickListener cb) {
        Button b = new Button(this);
        b.setText(label);
        b.setTextSize(11);
        b.setSingleLine(false);
        b.setMinWidth(0);
        b.setMinimumWidth(0);
        b.setPadding(0, 8, 0, 8);
        b.setTextColor(Color.WHITE);
        b.setBackgroundColor(Color.TRANSPARENT);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        b.setLayoutParams(lp);
        b.setOnClickListener(cb);
        return b;
    }

    private void showTreePanel() {
        String msg = "Tree is your OS layer.\n\n"
                + "• Home here is TreeOS — simple, no clutter\n"
                + "• Approvals mean something\n"
                + "• Xod plugs in here as the agent engine\n\n"
                + "v0.4 — open-source emulator build, Android 9+ (Poco-ready floor)\n"
                + "New: Calculator, Notes, Flashlight, About TreeOS.\n"
                + "Tip: long-press any app for its system info page.\n"
                + "Battery: " + batteryText();
        new AlertDialog.Builder(this)
                .setTitle("🌳 Tree")
                .setMessage(msg)
                .setPositiveButton("Got it", null)
                .setNeutralButton("About TreeOS", (d, w) -> {
                    try { startActivity(new Intent(this, AboutActivity.class)); }
                    catch (Exception ignored) {}
                })
                .show();
    }

    private String batteryText() {
        try {
            IntentFilter f = new IntentFilter(Intent.ACTION_BATTERY_CHANGED);
            Intent batt = registerReceiver(null, f);
            if (batt != null) {
                int level = batt.getIntExtra(BatteryManager.EXTRA_LEVEL, -1);
                int scale = batt.getIntExtra(BatteryManager.EXTRA_SCALE, 100);
                if (level >= 0) return (level * 100 / scale) + "%";
            }
        } catch (Exception ignored) {}
        return "—";
    }

    private void updateClock() {
        if (clockView == null) return;
        clockView.setText(new SimpleDateFormat("h:mm a", Locale.US).format(new Date()));
        String date = new SimpleDateFormat("EEE, MMM d", Locale.US).format(new Date());
        dateView.setText(date + "   •   🔋 " + batteryText());
    }

    private void loadApps() {
        if (cachedApps != null) {
            allApps.clear();
            allApps.addAll(cachedApps);
            filter("");
            return;
        }
        PackageManager pm = getPackageManager();
        Intent q = new Intent(Intent.ACTION_MAIN);
        q.addCategory(Intent.CATEGORY_LAUNCHER);
        List<ResolveInfo> infos = pm.queryIntentActivities(q, 0);
        allApps.clear();
        for (ResolveInfo ri : infos) {
            // Skip only the home activity itself; other TreeOS suite apps in
            // this package (Calculator, Notes, Flashlight, About) DO belong
            // in the grid as their own entries.
            if (ri.activityInfo.name.equals(MainActivity.class.getName())) continue;
            AppItem it = new AppItem();
            it.label = ri.loadLabel(pm).toString();
            it.pkg = ri.activityInfo.packageName;
            it.cls = ri.activityInfo.name;
            try { it.icon = ri.loadIcon(pm); } catch (Exception ignored) {}
            allApps.add(it);
        }
        Collections.sort(allApps, Comparator.comparing(a -> a.label.toLowerCase(Locale.US)));
        cachedApps = new ArrayList<>(allApps);
        filter("");
    }

    private void filter(String needle) {
        shownApps.clear();
        String n = needle == null ? "" : needle.toLowerCase(Locale.US).trim();
        for (AppItem it : allApps) {
            if (n.isEmpty() || it.label.toLowerCase(Locale.US).contains(n)) shownApps.add(it);
        }
        if (adapter != null) adapter.notifyDataSetChanged();
    }

    @Override protected void onResume() {
        super.onResume();
        updateClock();
        // After a recreation (e.g. rotation) the search box text is restored
        // without re-firing the text watcher, so the grid can show every app
        // while the box still holds a query. Re-apply the filter to resync —
        // immediately, and once more shortly after in case the state restore
        // lands after onResume on this Android version.
        if (searchBox != null) filter(searchBox.getText().toString());
        handler.postDelayed(() -> {
            if (searchBox != null) filter(searchBox.getText().toString());
        }, 400);
        handler.removeCallbacks(tick);
        handler.post(tick);
    }

    @Override protected void onPause() {
        super.onPause();
        handler.removeCallbacks(tick);
    }

    // Back should do nothing in a launcher — you're already home.
    @Override public void onBackPressed() { /* stay home */ }

    class AppAdapter extends BaseAdapter {
        @Override public int getCount() { return shownApps.size(); }
        @Override public Object getItem(int p) { return shownApps.get(p); }
        @Override public long getItemId(int p) { return p; }
        @Override public View getView(int p, View convert, ViewGroup parent) {
            LinearLayout cell;
            ImageView iv;
            TextView tv;
            if (convert == null) {
                cell = new LinearLayout(MainActivity.this);
                cell.setOrientation(LinearLayout.VERTICAL);
                cell.setGravity(Gravity.CENTER);
                cell.setPadding(6, 10, 6, 10);
                iv = new ImageView(MainActivity.this);
                iv.setLayoutParams(new LinearLayout.LayoutParams(120, 120));
                iv.setTag("icon");
                cell.addView(iv);
                tv = new TextView(MainActivity.this);
                tv.setTextColor(Color.WHITE);
                tv.setTextSize(12);
                tv.setGravity(Gravity.CENTER);
                tv.setMaxLines(2);
                tv.setEllipsize(TextUtils.TruncateAt.END);
                tv.setTag("label");
                cell.addView(tv);
            } else {
                cell = (LinearLayout) convert;
                iv = (ImageView) cell.findViewWithTag("icon");
                tv = (TextView) cell.findViewWithTag("label");
            }
            AppItem it = shownApps.get(p);
            iv.setImageDrawable(it.icon);
            tv.setText(it.label);
            return cell;
        }
    }
}
