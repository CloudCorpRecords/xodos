package dev.treeos.launcher;

import android.app.Activity;
import android.graphics.Color;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;

/** Shared TreeOS visual style: dark-green background, green accents, white text. */
final class Ui {
    static final int GREEN = Color.rgb(122, 199, 79);
    static final int DARK = Color.rgb(11, 26, 16);
    static final int PANEL = Color.rgb(18, 38, 24);
    static final int SOFT = Color.rgb(190, 220, 180);
    static final int DIM = Color.rgb(150, 170, 150);

    private Ui() {}

    static LinearLayout root(Activity a) {
        LinearLayout r = new LinearLayout(a);
        r.setOrientation(LinearLayout.VERTICAL);
        r.setBackgroundColor(DARK);
        r.setPadding(36, 36, 36, 24);
        return r;
    }

    static TextView title(Activity a, String text) {
        TextView t = new TextView(a);
        t.setText(text);
        t.setTextColor(GREEN);
        t.setTextSize(22);
        t.setGravity(Gravity.CENTER);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, 0, 0, 20);
        t.setLayoutParams(lp);
        return t;
    }

    static Button button(Activity a, String text) {
        Button b = new Button(a);
        b.setText(text);
        b.setTextSize(16);
        b.setTextColor(Color.WHITE);
        b.setBackgroundColor(PANEL);
        b.setPadding(16, 14, 16, 14);
        return b;
    }

    static TextView body(Activity a, String text) {
        TextView t = new TextView(a);
        t.setText(text);
        t.setTextColor(Color.WHITE);
        t.setTextSize(16);
        return t;
    }
}
