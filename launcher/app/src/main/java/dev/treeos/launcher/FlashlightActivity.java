package dev.treeos.launcher;

import android.app.Activity;
import android.content.Context;
import android.content.pm.PackageManager;
import android.hardware.camera2.CameraAccessException;
import android.hardware.camera2.CameraCharacteristics;
import android.hardware.camera2.CameraManager;
import android.os.Bundle;
import android.view.Gravity;
import android.view.ViewGroup;
import android.widget.Button;
import android.widget.LinearLayout;
import android.widget.TextView;
import android.widget.Toast;

/**
 * TreeOS Flashlight — camera torch via CameraManager.setTorchMode.
 * No CAMERA permission is required for torch mode. If the device (or the
 * emulator's virtual camera) has no flash unit, the app says so plainly
 * instead of crashing.
 */
public class FlashlightActivity extends Activity {

    private String torchCameraId = null;
    private boolean torchOn = false;
    private Button toggle;
    private TextView status;

    private final CameraManager.TorchCallback torchCallback = new CameraManager.TorchCallback() {
        @Override public void onTorchModeChanged(String cameraId, boolean enabled) {
            if (cameraId.equals(torchCameraId)) {
                torchOn = enabled;
                refresh();
            }
        }
        @Override public void onTorchModeUnavailable(String cameraId) {
            if (cameraId.equals(torchCameraId)) refresh();
        }
    };

    @Override
    protected void onCreate(Bundle savedInstanceState) {
        super.onCreate(savedInstanceState);

        LinearLayout root = Ui.root(this);
        root.addView(Ui.title(this, "🔦 Flashlight"));

        status = Ui.body(this, "");
        status.setGravity(Gravity.CENTER);
        root.addView(status);

        toggle = Ui.button(this, "Turn on");
        toggle.setTextSize(20);
        LinearLayout.LayoutParams lp = new LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT, ViewGroup.LayoutParams.WRAP_CONTENT);
        lp.setMargins(0, 28, 0, 0);
        toggle.setLayoutParams(lp);
        toggle.setOnClickListener(v -> flip());
        root.addView(toggle);
        setContentView(root);

        findTorchCamera();
        refresh();
    }

    private void findTorchCamera() {
        torchCameraId = null;
        if (!getPackageManager().hasSystemFeature(PackageManager.FEATURE_CAMERA_FLASH)) {
            // Still probe directly: some devices expose a torch without the feature flag.
        }
        try {
            CameraManager cm = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            if (cm == null) return;
            for (String id : cm.getCameraIdList()) {
                CameraCharacteristics cc = cm.getCameraCharacteristics(id);
                Boolean flash = cc.get(CameraCharacteristics.FLASH_INFO_AVAILABLE);
                Integer facing = cc.get(CameraCharacteristics.LENS_FACING);
                if (flash != null && flash) {
                    torchCameraId = id;
                    if (facing != null && facing == CameraCharacteristics.LENS_FACING_BACK) break;
                }
            }
        } catch (Exception ignored) {
            torchCameraId = null;
        }
    }

    private void flip() {
        if (torchCameraId == null) return;
        try {
            CameraManager cm = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            if (cm == null) return;
            cm.setTorchMode(torchCameraId, !torchOn);
            torchOn = !torchOn; // callback will confirm/sync
        } catch (CameraAccessException | SecurityException | IllegalArgumentException e) {
            Toast.makeText(this, "Torch unavailable right now", Toast.LENGTH_SHORT).show();
        }
        refresh();
    }

    private void refresh() {
        if (status == null || toggle == null) return;
        if (torchCameraId == null) {
            status.setText("No flash on this device");
            toggle.setText("Unavailable");
            toggle.setEnabled(false);
        } else {
            status.setText(torchOn ? "On" : "Off");
            toggle.setText(torchOn ? "Turn off" : "Turn on");
            toggle.setEnabled(true);
        }
    }

    @Override
    protected void onResume() {
        super.onResume();
        try {
            CameraManager cm = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            if (cm != null) cm.registerTorchCallback(torchCallback, null);
        } catch (Exception ignored) {}
        refresh();
    }

    @Override
    protected void onPause() {
        try {
            CameraManager cm = (CameraManager) getSystemService(Context.CAMERA_SERVICE);
            if (cm != null) cm.unregisterTorchCallback(torchCallback);
        } catch (Exception ignored) {}
        super.onPause();
    }
}
