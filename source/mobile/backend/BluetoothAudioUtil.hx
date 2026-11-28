package mobile.backend;

import backend.ClientPrefs;
#if android
import lime.system.JNI;
#end

/**
 * Low-latency & Bluetooth Audio manager for Psych Engine Mobile Beta.
 * Bridges Android's PsychAudio JNI callbacks to automatically apply separate Bluetooth note offsets
 * and optionally mute delayed hitsound clicks when playing on wireless headphones.
 */
class BluetoothAudioUtil
{
	static var _initialized:Bool = false;
	static var _cachedBtConnected:Bool = false;
	static var _cachedLatencyMs:Int = 0;
	static var _cachedDeviceName:String = '';
	static var _pollAccum:Float = 999.0;

	#if android
	static var _jniInit:Dynamic = null;
	static var _jniIsBtConnected:Dynamic = null;
	static var _jniGetLatencyMs:Dynamic = null;
	static var _jniGetDeviceName:Dynamic = null;
	#end

	public static function init():Void
	{
		if (_initialized)
		{
			refreshState();
			return;
		}

		#if android
		try
		{
			if (_jniInit == null)
				_jniInit = JNI.createStaticMethod('org/haxe/extension/PsychAudio', 'init', '()V');
			if (_jniIsBtConnected == null)
				_jniIsBtConnected = JNI.createStaticMethod('org/haxe/extension/PsychAudio', 'isBluetoothConnected', '()Z');
			if (_jniGetLatencyMs == null)
				_jniGetLatencyMs = JNI.createStaticMethod('org/haxe/extension/PsychAudio', 'getEstimatedLatencyMs', '()I');
			if (_jniGetDeviceName == null)
				_jniGetDeviceName = JNI.createStaticMethod('org/haxe/extension/PsychAudio', 'getActiveBluetoothDeviceName', '()Ljava/lang/String;');

			if (_jniInit != null)
				_jniInit();

			_initialized = true;
			refreshState();
		}
		catch (e:Dynamic)
		{
			trace('[BluetoothAudioUtil] Failed to initialize PsychAudio JNI: $e');
			_initialized = true;
		}
		#else
		_initialized = true;
		#end
	}

	/**
	 * Refreshes cached Bluetooth connection state and HAL output latency from Android.
	 */
	public static function refreshState():Void
	{
		#if android
		if (!_initialized)
			init();

		try
		{
			var btActive:Bool = (_jniIsBtConnected != null && _jniIsBtConnected() == true);
			_cachedBtConnected = btActive;

			if (btActive)
			{
				var lat:Dynamic = (_jniGetLatencyMs != null) ? _jniGetLatencyMs() : 165;
				_cachedLatencyMs = (lat != null) ? Std.int(lat) : 165;
				if (_cachedLatencyMs <= 0)
					_cachedLatencyMs = 165;

				var dev:Dynamic = (_jniGetDeviceName != null) ? _jniGetDeviceName() : 'Bluetooth';
				_cachedDeviceName = (dev != null && Std.string(dev).length > 0) ? Std.string(dev) : 'Bluetooth';
			}
			else
			{
				_cachedLatencyMs = 0;
				_cachedDeviceName = '';
			}
		}
		catch (e:Dynamic)
		{
			_cachedBtConnected = false;
			_cachedLatencyMs = 0;
			_cachedDeviceName = '';
		}
		#end
	}

	/**
	 * Lightweight periodic poll (e.g. every 0.5s during gameplay/calibration) to catch route changes.
	 */
	public static inline function poll(elapsed:Float, interval:Float = 0.5):Void
	{
		_pollAccum += elapsed;
		if (_pollAccum >= interval)
		{
			_pollAccum = 0.0;
			refreshState();
		}
	}

	public static inline function isBluetoothConnected():Bool
	{
		#if android
		if (!_initialized)
			init();
		return _cachedBtConnected;
		#else
		return false;
		#end
	}

	public static inline function getDetectedLatencyMs():Int
	{
		#if android
		if (!_initialized)
			init();
		return _cachedBtConnected ? _cachedLatencyMs : 0;
		#else
		return 0;
		#end
	}

	public static inline function getDeviceName():String
	{
		#if android
		return _cachedBtConnected ? _cachedDeviceName : '';
		#else
		return '';
		#end
	}

	/**
	 * Returns the additional note offset (in ms) contributed by Bluetooth audio compensation.
	 * Returns 0 when on phone speakers / wired headphones or when Bluetooth Auto-Offset is disabled.
	 */
	public static function getActiveBluetoothOffset():Int
	{
		#if android
		if (ClientPrefs.data == null || !ClientPrefs.data.bluetoothAutoOffset)
			return 0;

		if (!isBluetoothConnected())
			return 0;

		var autoBase:Int = ClientPrefs.data.bluetoothAutoDetect ? getDetectedLatencyMs() : 0;
		return autoBase + ClientPrefs.data.bluetoothOffset;
		#else
		return 0;
		#end
	}

	/**
	 * Returns true if hitsounds should be muted right now to prevent delayed Bluetooth hitsound clicks
	 * from throwing off the player's rhythm.
	 */
	public static inline function shouldMuteHitsounds():Bool
	{
		#if android
		return ClientPrefs.data != null
			&& ClientPrefs.data.bluetoothMuteHitsound
			&& isBluetoothConnected();
		#else
		return false;
		#end
	}
}
