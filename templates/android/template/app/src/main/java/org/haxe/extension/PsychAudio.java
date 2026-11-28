package org.haxe.extension;

import android.app.Activity;
import android.content.Context;
import android.media.AudioDeviceCallback;
import android.media.AudioDeviceInfo;
import android.media.AudioManager;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import java.lang.reflect.Method;

/**
 * Native Android Low-Latency & Bluetooth Audio helper for Psych Engine Mobile Beta.
 * Detects Bluetooth A2DP / BLE / SCO output routes in real time with zero per-frame IPC
 * and queries Android's AudioFlinger / HAL output latency for automatic note offset compensation.
 */
public class PsychAudio {
	// AudioDeviceInfo constants (numeric values for full SDK compatibility across API 23..36)
	private static final int TYPE_BLUETOOTH_SCO = 7;
	private static final int TYPE_BLUETOOTH_A2DP = 8;
	private static final int TYPE_HEARING_AID = 23;
	private static final int TYPE_BLE_HEADSET = 26;
	private static final int TYPE_BLE_SPEAKER = 27;
	private static final int TYPE_BLE_BROADCAST = 30;

	private static volatile boolean initialized = false;
	private static volatile boolean bluetoothConnected = false;
	private static volatile boolean isBleAudio = false;
	private static volatile String activeDeviceName = "";
	private static volatile int nativeSampleRate = 48000;
	private static volatile int nativeBufferSize = 192;

	private static AudioManager audioManager = null;
	private static Method getOutputLatencyMethod = null;
	private static boolean latencyMethodChecked = false;

	public static void init() {
		if (initialized) {
			refreshBluetoothState();
			return;
		}

		try {
			final Context ctx = Extension.mainContext;
			if (ctx == null) {
				return;
			}

			audioManager = (AudioManager) ctx.getSystemService(Context.AUDIO_SERVICE);
			if (audioManager == null) {
				return;
			}

			// Ensure normal stereo A2DP media mode (never SCO voice mode) and hardware game volume stream
			try {
				if (audioManager.getMode() != AudioManager.MODE_NORMAL) {
					audioManager.setMode(AudioManager.MODE_NORMAL);
				}
			} catch (Throwable ignored) {
			}

			final Activity act = Extension.mainActivity;
			if (act != null) {
				act.runOnUiThread(new Runnable() {
					@Override
					public void run() {
						try {
							act.setVolumeControlStream(AudioManager.STREAM_MUSIC);
						} catch (Throwable ignored) {
						}
					}
				});
			}

			if (Build.VERSION.SDK_INT >= 17) {
				try {
					String sr = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_SAMPLE_RATE);
					if (sr != null && sr.length() > 0) {
						int parsedSr = Integer.parseInt(sr.trim());
						if (parsedSr >= 8000 && parsedSr <= 192000) {
							nativeSampleRate = parsedSr;
						}
					}
					String fpb = audioManager.getProperty(AudioManager.PROPERTY_OUTPUT_FRAMES_PER_BUFFER);
					if (fpb != null && fpb.length() > 0) {
						int parsedFpb = Integer.parseInt(fpb.trim());
						if (parsedFpb >= 16 && parsedFpb <= 8192) {
							nativeBufferSize = parsedFpb;
						}
					}
				} catch (Throwable ignored) {
				}
			}

			refreshBluetoothState();

			if (Build.VERSION.SDK_INT >= 23) {
				Handler handler = new Handler(Looper.getMainLooper());
				audioManager.registerAudioDeviceCallback(new AudioDeviceCallback() {
					@Override
					public void onAudioDevicesAdded(AudioDeviceInfo[] addedDevices) {
						refreshBluetoothState();
					}

					@Override
					public void onAudioDevicesRemoved(AudioDeviceInfo[] removedDevices) {
						refreshBluetoothState();
					}
				}, handler);
			}

			initialized = true;
		} catch (Throwable ignored) {
		}
	}

	public static void refreshBluetoothState() {
		if (audioManager == null) {
			bluetoothConnected = false;
			isBleAudio = false;
			activeDeviceName = "";
			return;
		}

		boolean foundBt = false;
		boolean foundBle = false;
		String foundName = "";

		try {
			if (Build.VERSION.SDK_INT >= 23) {
				AudioDeviceInfo[] devices = audioManager.getDevices(AudioManager.GET_DEVICES_OUTPUTS);
				if (devices != null) {
					for (int i = 0; i < devices.length; i++) {
						AudioDeviceInfo dev = devices[i];
						if (dev == null) continue;
						int type = dev.getType();
						if (isBluetoothOutputType(type)) {
							foundBt = true;
							if (type == TYPE_BLE_HEADSET || type == TYPE_BLE_SPEAKER || type == TYPE_BLE_BROADCAST) {
								foundBle = true;
							}
							CharSequence prodName = dev.getProductName();
							if (prodName != null && prodName.length() > 0) {
								foundName = prodName.toString().trim();
							}
							// Prefer A2DP / BLE headset name if multiple outputs exist
							if (type == TYPE_BLUETOOTH_A2DP || type == TYPE_BLE_HEADSET) {
								break;
							}
						}
					}
				}
			} else {
				@SuppressWarnings("deprecation")
				boolean a2dp = audioManager.isBluetoothA2dpOn() || audioManager.isBluetoothScoOn();
				foundBt = a2dp;
			}
		} catch (Throwable ignored) {
		}

		bluetoothConnected = foundBt;
		isBleAudio = foundBle;
		activeDeviceName = foundBt ? (foundName.length() > 0 ? foundName : "Bluetooth") : "";
	}

	private static boolean isBluetoothOutputType(int type) {
		return type == TYPE_BLUETOOTH_A2DP
			|| type == TYPE_BLUETOOTH_SCO
			|| type == TYPE_HEARING_AID
			|| type == TYPE_BLE_HEADSET
			|| type == TYPE_BLE_SPEAKER
			|| type == TYPE_BLE_BROADCAST;
	}

	public static boolean isBluetoothConnected() {
		if (!initialized) {
			init();
		}
		return bluetoothConnected;
	}

	public static String getActiveBluetoothDeviceName() {
		if (!initialized) {
			init();
		}
		return activeDeviceName != null ? activeDeviceName : "";
	}

	/**
	 * Queries the real HAL / AudioFlinger output latency in milliseconds when Bluetooth is active.
	 * Falls back to realistic codec defaults (110ms for LE Audio, 165ms for A2DP) if the OEM HAL hides latency.
	 */
	public static int getEstimatedLatencyMs() {
		if (!isBluetoothConnected()) {
			return 0;
		}

		int fallbackMs = isBleAudio ? 110 : 165;
		if (audioManager == null) {
			return fallbackMs;
		}

		try {
			if (!latencyMethodChecked) {
				latencyMethodChecked = true;
				try {
					getOutputLatencyMethod = AudioManager.class.getMethod("getOutputLatency", int.class);
				} catch (Throwable ignored) {
					getOutputLatencyMethod = null;
				}
			}

			if (getOutputLatencyMethod != null) {
				Object result = getOutputLatencyMethod.invoke(audioManager, AudioManager.STREAM_MUSIC);
				if (result instanceof Integer) {
					int reportedMs = ((Integer) result).intValue();
					// Some OEMs return only internal mixer latency (~20ms) even on A2DP; validate > 45ms
					if (reportedMs >= 45 && reportedMs <= 600) {
						return reportedMs;
					}
				}
			}
		} catch (Throwable ignored) {
		}

		return fallbackMs;
	}

	public static int getNativeSampleRate() {
		if (!initialized) {
			init();
		}
		return nativeSampleRate;
	}

	public static int getNativeBufferSize() {
		if (!initialized) {
			init();
		}
		return nativeBufferSize;
	}
}
