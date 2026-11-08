package dev.treeos.launcher;

import android.app.Activity;
import android.content.pm.PackageInfo;
import android.os.Build;
import android.os.Bundle;
import android.widget.LinearLayout;
import android.widget.ScrollView;
import android.widget.TextView;

/**
 * TreeOS "About this OS" — version, build, and the open-source story in one
 * plain page. Reached from the app grid and from the Tree panel.
 */
public class AboutActivity extends Activity {

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        String versionName = "0.4.0";
        long versionCode = 4;
        try {
            PackageInfo pi = getPackageManager().getPackageInfo(getPackageName(), 0);
            versionName = pi.versionName;
            versionCode = pi.getLongVersionCode();
        } catch (Exception ignored) {}

        LinearLayout root = Ui.root(this);
        root.addView(Ui.title(this, "🌳 About TreeOS"));

        String text =
                "TreeOS " + versionName + " (build " + versionCode + ")\n"
                + "by Rene Turcios + Tree\n\n"
                + "TreeOS is an open-source phone OS.\n\n"
                + "• The TreeOS launcher and apps in this package are ours — "
                + "plain Java, no trackers, no ads, source published with the project.\n"
                + "• The base system is AOSP (Apache License 2.0) on the Linux kernel (GPLv2).\n"
                + "• The current test image also includes Google apps (Chrome, Gmail, Maps, "
                + "YouTube, Play services). Those are Google-proprietary, ship only in the "
                + "emulator test base, and are NOT part of TreeOS's open source.\n"
                + "• The full list of everything the TreeOS image adds — every file, path, "
                + "and hash — is in docs/CONTENT-MANIFEST.md in the TreeOS repo. "
                + "That manifest IS the OS spec: the same content builds the emulator "
                + "image today and the phone (GSI) image next.\n\n"
                + "Running on: Android " + Build.VERSION.RELEASE
                + " (API " + Build.VERSION.SDK_INT + ")\n"
                + "Device: " + Build.MANUFACTURER + " " + Build.MODEL + "\n"
                + "Launcher package: " + getPackageName() + "\n";

        TextView body = Ui.body(this, text);
        body.setTextSize(15);
        body.setLineSpacing(1.25f, 1f);

        ScrollView scroll = new ScrollView(this);
        scroll.addView(body);
        root.addView(scroll);
        setContentView(root);
    }
}
