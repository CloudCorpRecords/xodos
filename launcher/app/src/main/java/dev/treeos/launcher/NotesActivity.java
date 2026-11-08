package dev.treeos.launcher;

import android.app.Activity;
import android.content.SharedPreferences;
import android.os.Bundle;
import android.view.ViewGroup;
import android.widget.ArrayAdapter;
import android.widget.Button;
import android.widget.EditText;
import android.widget.LinearLayout;
import android.widget.ListView;
import android.widget.Toast;

import org.json.JSONArray;
import org.json.JSONObject;

import java.util.ArrayList;
import java.util.List;

/**
 * TreeOS Notes — create / edit / delete plain-text notes, persisted in the
 * app's own SharedPreferences storage (survives process death and reboot;
 * cleared only by wiping app data, like any local notes app).
 */
public class NotesActivity extends Activity {

    private static final String PREFS = "treeos_notes";
    private static final String KEY = "notes_json";

    static class Note {
        String title;
        String body;
        long updated;
    }

    private List<Note> notes = new ArrayList<>();
    private int editing = -1; // index into notes, or -1 for list view / new note handled via -2
    private EditText titleBox;
    private EditText bodyBox;

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);
        load();
        showList();
    }

    private void load() {
        notes.clear();
        try {
            String raw = getSharedPreferences(PREFS, MODE_PRIVATE).getString(KEY, "[]");
            JSONArray arr = new JSONArray(raw);
            for (int i = 0; i < arr.length(); i++) {
                JSONObject o = arr.getJSONObject(i);
                Note n = new Note();
                n.title = o.optString("t", "");
                n.body = o.optString("b", "");
                n.updated = o.optLong("u", 0);
                notes.add(n);
            }
        } catch (Exception ignored) {
            notes.clear();
        }
    }

    private void save() {
        try {
            JSONArray arr = new JSONArray();
            for (Note n : notes) {
                JSONObject o = new JSONObject();
                o.put("t", n.title);
                o.put("b", n.body);
                o.put("u", n.updated);
                arr.put(o);
            }
            SharedPreferences.Editor e = getSharedPreferences(PREFS, MODE_PRIVATE).edit();
            e.putString(KEY, arr.toString());
            e.apply();
        } catch (Exception ignored) {}
    }

    private void showList() {
        editing = -1;
        LinearLayout root = Ui.root(this);
        root.addView(Ui.title(this, "📝 Notes"));

        Button add = Ui.button(this, "＋ New note");
        add.setOnClickListener(v -> showEditor(-2));
        root.addView(add);

        ListView list = new ListView(this);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        lp.setMargins(0, 16, 0, 0);
        list.setLayoutParams(lp);
        List<String> labels = new ArrayList<>();
        for (Note n : notes) {
            String t = n.title.trim().isEmpty() ? "(untitled)" : n.title.trim();
            labels.add(t);
        }
        if (labels.isEmpty()) labels.add("No notes yet — tap ＋ New note");
        ArrayAdapter<String> ad = new ArrayAdapter<>(this,
                android.R.layout.simple_list_item_1, labels);
        list.setAdapter(ad);
        list.setOnItemClickListener((p, v, pos, id) -> {
            if (!notes.isEmpty()) showEditor(pos);
        });
        root.addView(list);
        setContentView(root);
    }

    private void showEditor(int index) {
        editing = index; // -2 = new note
        Note existing = (index >= 0 && index < notes.size()) ? notes.get(index) : null;

        LinearLayout root = Ui.root(this);
        root.addView(Ui.title(this, existing == null ? "📝 New note" : "📝 Note"));

        titleBox = new EditText(this);
        titleBox.setHint("Title");
        titleBox.setSingleLine(true);
        titleBox.setTextColor(android.graphics.Color.WHITE);
        titleBox.setHintTextColor(Ui.DIM);
        titleBox.setBackgroundColor(Ui.PANEL);
        titleBox.setPadding(20, 14, 20, 14);
        if (existing != null) titleBox.setText(existing.title);
        root.addView(titleBox);

        bodyBox = new EditText(this);
        bodyBox.setHint("Write here…");
        bodyBox.setTextColor(android.graphics.Color.WHITE);
        bodyBox.setHintTextColor(Ui.DIM);
        bodyBox.setBackgroundColor(Ui.PANEL);
        bodyBox.setPadding(20, 14, 20, 14);
        bodyBox.setGravity(android.view.Gravity.TOP | android.view.Gravity.START);
        LinearLayout.LayoutParams bp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f);
        bp.setMargins(0, 12, 0, 12);
        bodyBox.setLayoutParams(bp);
        if (existing != null) bodyBox.setText(existing.body);
        root.addView(bodyBox);

        LinearLayout row = new LinearLayout(this);
        row.setOrientation(LinearLayout.HORIZONTAL);
        Button saveBtn = Ui.button(this, "Save");
        LinearLayout.LayoutParams sb = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
        sb.setMargins(0, 0, 8, 0);
        saveBtn.setLayoutParams(sb);
        saveBtn.setOnClickListener(v -> {
            Note n = existing == null ? new Note() : existing;
            n.title = titleBox.getText().toString();
            n.body = bodyBox.getText().toString();
            n.updated = System.currentTimeMillis();
            if (existing == null) notes.add(0, n);
            save();
            Toast.makeText(this, "Saved", Toast.LENGTH_SHORT).show();
            showList();
        });
        row.addView(saveBtn);

        if (existing != null) {
            Button del = Ui.button(this, "Delete");
            LinearLayout.LayoutParams db = new LinearLayout.LayoutParams(0, ViewGroup.LayoutParams.WRAP_CONTENT, 1f);
            db.setMargins(8, 0, 0, 0);
            del.setLayoutParams(db);
            del.setOnClickListener(v -> {
                notes.remove(existing);
                save();
                Toast.makeText(this, "Deleted", Toast.LENGTH_SHORT).show();
                showList();
            });
            row.addView(del);
        }
        root.addView(row);
        setContentView(root);
    }

    @Override
    public void onBackPressed() {
        if (editing != -1) {
            showList();
        } else {
            super.onBackPressed();
        }
    }
}
