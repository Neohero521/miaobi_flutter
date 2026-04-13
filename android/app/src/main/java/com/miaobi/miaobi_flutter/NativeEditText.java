package com.miaobi.miaobi_flutter;

import android.view.ActionMode;
import android.app.Activity;
import android.content.Context;
import android.graphics.Color;
import android.graphics.drawable.ColorDrawable;
import android.text.Editable;
import android.text.Spannable;
import android.text.TextWatcher;
import android.util.Log;
import android.view.ActionMode.Callback;
import android.view.Gravity;
import android.view.Menu;
import android.view.MenuItem;
import android.view.View;
import android.widget.EditText;
import android.widget.LinearLayout;
import androidx.core.content.ContextCompat;

import java.util.Map;
import java.util.HashMap;

import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.platform.PlatformView;

public class NativeEditText implements PlatformView, Callback {
    private static final String TAG = "NativeEditText";
    private final EditText editText;
    private final MethodChannel channel;
    private final int viewId;
    private Activity activity;

    // Selection action codes
    private static final int ACTION_CUT = android.R.id.cut;
    private static final int ACTION_COPY = android.R.id.copy;
    private static final int ACTION_PASTE = android.R.id.paste;
    private static final int ACTION_SELECT_ALL = android.R.id.selectAll;
    // Custom actions
    private static final int ACTION_EXPAND = 1001;
    private static final int ACTION_SHRINK = 1002;
    private static final int ACTION_REWRITE = 1003;
    private static final int ACTION_DIRECTED = 1004;

    NativeEditText(Context context, int viewId, BinaryMessenger messenger, Object args) {
        this.viewId = viewId;
        this.activity = (Activity) context;

        // Create channel for communication with Flutter
        channel = new MethodChannel(messenger, "com.miaobi/native_edit_text_" + viewId);
        channel.setMethodCallHandler(this::onMethodCall);

        // Create EditText
        editText = new EditText(context);
        editText.setLayoutParams(new LinearLayout.LayoutParams(
            LinearLayout.LayoutParams.MATCH_PARENT,
            LinearLayout.LayoutParams.MATCH_PARENT
        ));
        editText.setBackground(new ColorDrawable(Color.TRANSPARENT));
        editText.setTextColor(Color.parseColor("#1A1A1A"));
        editText.setTextSize(16);
        editText.setLineSpacing(8, 1.8f);
        editText.setGravity(Gravity.TOP | Gravity.START);
        editText.setHintTextColor(Color.parseColor("#999999"));

        // Set custom selection action mode
        editText.setCustomSelectionActionModeCallback(this);

        // Handle text changes
        editText.addTextChangedListener(new TextWatcher() {
            @Override
            public void beforeTextChanged(CharSequence s, int start, int count, int after) {}

            @Override
            public void onTextChanged(CharSequence s, int start, int before, int count) {}

            @Override
            public void afterTextChanged(Editable s) {
                Map<String, Object> result = new HashMap<>();
                result.put("text", s.toString());
                result.put("selectionStart", editText.getSelectionStart());
                result.put("selectionEnd", editText.getSelectionEnd());
                channel.invokeMethod("onTextChanged", result);
            }
        });

        Log.d(TAG, "NativeEditText created with viewId: " + viewId);
    }

    private void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "setText":
                String text = call.argument("text");
                if (text != null) {
                    editText.setText(text);
                    result.success(true);
                } else {
                    result.error("INVALID_ARGUMENT", "text is null", null);
                }
                break;
            case "insertText":
                String insertedText = call.argument("text");
                Integer position = call.argument("position");
                if (insertedText != null) {
                    int pos = position != null ? position : editText.getSelectionStart();
                    editText.getText().insert(pos, insertedText);
                    result.success(true);
                } else {
                    result.error("INVALID_ARGUMENT", "text is null", null);
                }
                break;
            case "replaceText":
                Integer start = call.argument("start");
                Integer end = call.argument("end");
                String newText = call.argument("newText");
                if (start != null && end != null && newText != null) {
                    editText.getText().replace(start, end, newText);
                    result.success(true);
                } else {
                    result.error("INVALID_ARGUMENT", "start/end/newText required", null);
                }
                break;
            case "getSelection":
                result.success(java.util.Arrays.asList(
                    editText.getSelectionStart(),
                    editText.getSelectionEnd()
                ));
                break;
            default:
                result.notImplemented();
        }
    }

    @Override
    public View getView() {
        return editText;
    }

    @Override
    public void dispose() {
        Log.d(TAG, "Disposing NativeEditText with viewId: " + viewId);
    }

    // ===== ActionMode.Callback implementation =====

    @Override
    public boolean onCreateActionMode(ActionMode mode, Menu menu) {
        Log.d(TAG, "onCreateActionMode");
        
        // Clear default actions
        menu.clear();

        // Get selected text
        int start = editText.getSelectionStart();
        int end = editText.getSelectionEnd();
        boolean hasSelection = start != end;

        // Row 1: Cut, Copy, Paste, Select All, Expand
        menu.add(Menu.NONE, ACTION_CUT, Menu.NONE, "剪切");
        menu.add(Menu.NONE, ACTION_COPY, Menu.NONE, "复制");
        menu.add(Menu.NONE, ACTION_PASTE, Menu.NONE, "粘贴");
        menu.add(Menu.NONE, ACTION_SELECT_ALL, Menu.NONE, "全选");
        if (hasSelection) {
            menu.add(Menu.NONE, ACTION_EXPAND, Menu.NONE, "扩写");
        }

        // Row 2: Shrink, Rewrite, Directed Continue
        if (hasSelection) {
            menu.add(Menu.NONE, ACTION_SHRINK, Menu.NONE, "缩写");
            menu.add(Menu.NONE, ACTION_REWRITE, Menu.NONE, "改写");
            menu.add(Menu.NONE, ACTION_DIRECTED, Menu.NONE, "定向续写");
        }

        return true;
    }

    @Override
    public boolean onPrepareActionMode(ActionMode mode, Menu menu) {
        return false;
    }

    @Override
    public boolean onActionItemClicked(ActionMode mode, MenuItem item) {
        int itemId = item.getItemId();
        Log.d(TAG, "Action clicked: " + itemId);

        int start = editText.getSelectionStart();
        int end = editText.getSelectionEnd();
        String selectedText = "";
        if (start != end) {
            selectedText = editText.getText().toString().substring(start, end);
        }

        switch (itemId) {
            case ACTION_CUT:
                editText.onTextContextMenuItem(android.R.id.cut);
                mode.finish();
                return true;
            case ACTION_COPY:
                editText.onTextContextMenuItem(android.R.id.copy);
                mode.finish();
                return true;
            case ACTION_PASTE:
                editText.onTextContextMenuItem(android.R.id.paste);
                mode.finish();
                return true;
            case ACTION_SELECT_ALL:
                editText.onTextContextMenuItem(android.R.id.selectAll);
                mode.finish();
                return true;
            case ACTION_EXPAND:
                sendActionToFlutter("expand", selectedText, start, end);
                mode.finish();
                return true;
            case ACTION_SHRINK:
                sendActionToFlutter("shrink", selectedText, start, end);
                mode.finish();
                return true;
            case ACTION_REWRITE:
                sendActionToFlutter("rewrite", selectedText, start, end);
                mode.finish();
                return true;
            case ACTION_DIRECTED:
                sendActionToFlutter("directed", selectedText, start, end);
                mode.finish();
                return true;
            default:
                return false;
        }
    }

    @Override
    public void onDestroyActionMode(ActionMode mode) {
        Log.d(TAG, "onDestroyActionMode");
    }

    private void sendActionToFlutter(String action, String selectedText, int start, int end) {
        Map<String, Object> data = new HashMap<>();
        data.put("action", action);
        data.put("selectedText", selectedText);
        data.put("start", start);
        data.put("end", end);
        channel.invokeMethod("onSelectionAction", data);
    }
}
