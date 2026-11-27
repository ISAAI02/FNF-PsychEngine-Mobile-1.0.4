package mobile.backend;

import flixel.math.FlxMath;
import flixel.tweens.FlxTween;
import backend.ClientPrefs;
#if FEATURE_HAPTICS
import extension.haptics.Haptic;
#end

/**
 * Haptic feedback utility modeled on official FNF Mobile (V-Slice) HapticUtil & NoteVibrationsHandler.
 */
class HapticUtil
{
	public static inline var DEFAULT_VIBRATION_PERIOD:Float = 0.1;
	public static inline var DEFAULT_VIBRATION_DURATION:Float = 0.5;
	public static inline var DEFAULT_VIBRATION_AMPLITUDE:Float = 0.5;
	public static inline var DEFAULT_VIBRATION_SHARPNESS:Float = 0.5;
	public static inline var MAX_VIBRATION_AMPLITUDE:Float = 1.0;

	public static inline var DEFAULT_NOTE_HIT_DURATION:Float = 0.01;
	public static inline var DEFAULT_NOTE_HIT_AMPLITUDE:Float = 0.25;
	public static inline var DEFAULT_NOTE_HIT_SHARPNESS:Float = 1.0;

	public static var amplitudeTween:FlxTween = null;

	static var _queuedNoteHits:Int = 0;
	static var _holdTimer:Float = 0.0;
	static var _initialized:Bool = false;

	public static var hapticsAvailable(get, never):Bool;

	static function get_hapticsAvailable():Bool
	{
		#if FEATURE_HAPTICS
		if (ClientPrefs.data != null && ClientPrefs.data.hapticsMode != 'None' && ClientPrefs.data.hapticsIntensity > 0.0)
			return true;
		#end
		return false;
	}

	public static function init():Void
	{
		#if FEATURE_HAPTICS
		if (!_initialized)
		{
			try
			{
				Haptic.initialize();
				_initialized = true;
			}
			catch (e:Dynamic)
			{
				trace('[HapticUtil] Failed to initialize haptics: $e');
			}
		}
		#end
	}

	/**
	 * Triggers a one-shot or patterned haptic vibration scaled by ClientPrefs.data.hapticsIntensity (0.0 to 1.0).
	 */
	public static function vibrate(period:Float = 0.0, duration:Float = 0.1, amplitude:Float = 0.5, sharpness:Float = 0.5, notesOnlyCompatible:Bool = false):Void
	{
		#if FEATURE_HAPTICS
		if (!hapticsAvailable)
			return;

		if (ClientPrefs.data.hapticsMode == 'Notes Only' && !notesOnlyCompatible)
			return;

		if (!_initialized)
			init();

		var intensity:Float = FlxMath.bound(ClientPrefs.data.hapticsIntensity, 0.0, 1.0);
		var amplitudeValue:Float = FlxMath.bound(amplitude * intensity, 0.0, MAX_VIBRATION_AMPLITUDE);
		if (amplitudeValue <= 0.0 || duration <= 0.0)
			return;

		var sharpValue:Float = FlxMath.bound(sharpness, 0.0, 1.0);

		try
		{
			if (period > 0.0)
			{
				var durations:Array<Float> = [];
				var amplitudes:Array<Float> = [];
				var sharpnesses:Array<Float> = [];

				var durationPeriod:Float = period / 2.0;
				if (durationPeriod <= 0.001)
					durationPeriod = 0.001;

				var steps:Int = Math.ceil(duration / durationPeriod);
				for (i in 0...steps)
				{
					durations.push(durationPeriod);
					amplitudes.push(amplitudeValue);
					sharpnesses.push(sharpValue);
				}

				Haptic.vibratePattern(durations, amplitudes, sharpnesses);
			}
			else
			{
				Haptic.vibrateOneShot(duration, amplitudeValue, sharpValue);
			}
		}
		catch (e:Dynamic) {}
		#end
	}

	/**
	 * Queues a note hit for this frame so simultaneous chord hits stack amplitude like V-Slice Mobile.
	 */
	public static inline function registerNoteHit():Void
	{
		_queuedNoteHits++;
	}

	/**
	 * Flushes queued note hits once per frame and handles subtle sustain-tail hold feedback.
	 */
	public static function flushNoteHits(elapsed:Float, holdingSustain:Bool = false):Void
	{
		if (_queuedNoteHits > 0)
		{
			var stackedAmplitude:Float = FlxMath.bound(DEFAULT_NOTE_HIT_AMPLITUDE * 2.5 * _queuedNoteHits, 0.0, MAX_VIBRATION_AMPLITUDE);
			_queuedNoteHits = 0;
			_holdTimer = 0.035;
			vibrate(0.0, DEFAULT_NOTE_HIT_DURATION, stackedAmplitude, DEFAULT_NOTE_HIT_SHARPNESS, true);
		}
		else if (holdingSustain)
		{
			_holdTimer -= elapsed;
			if (_holdTimer <= 0.0)
			{
				_holdTimer = 0.04;
				vibrate(0.0, 0.008, 0.2, 0.4, true);
			}
		}
		else
		{
			_holdTimer = 0.0;
		}
	}

	public static inline function resetNoteHits():Void
	{
		_queuedNoteHits = 0;
		_holdTimer = 0.0;
	}

	public static inline function vibrateMiss():Void
	{
		vibrate(0.0, 0.045, 0.45, 0.2, false);
	}

	public static inline function vibrateCountdown(isGo:Bool):Void
	{
		if (isGo)
			vibrate(0.0, 0.08, 0.75, 0.8, false);
		else
			vibrate(0.0, 0.03, 0.35, 0.6, false);
	}

	public static inline function vibrateMenuTick():Void
	{
		vibrate(0.0, 0.008, 0.2, 0.8, false);
	}

	public static inline function vibrateMenuConfirm():Void
	{
		vibrate(0.0, 0.025, 0.5, 0.85, false);
	}

	public static inline function vibrateGameOver():Void
	{
		vibrate(DEFAULT_VIBRATION_PERIOD, DEFAULT_VIBRATION_DURATION, 0.85, DEFAULT_VIBRATION_SHARPNESS, false);
	}

	public static function increasingVibrate(startAmplitude:Float, targetAmplitude:Float, tweenDuration:Float = 1.0):Void
	{
		#if FEATURE_HAPTICS
		if (!hapticsAvailable)
			return;

		if (amplitudeTween != null)
			amplitudeTween.cancel();

		amplitudeTween = FlxTween.num(startAmplitude, targetAmplitude, tweenDuration, {
			onComplete: (_) ->
			{
				vibrate(DEFAULT_VIBRATION_PERIOD, DEFAULT_VIBRATION_DURATION, targetAmplitude * 2.0, DEFAULT_VIBRATION_SHARPNESS, false);
				amplitudeTween = null;
			}
		}, (currentAmplitude:Float) ->
		{
			vibrate(0.0, DEFAULT_VIBRATION_DURATION / 10.0, currentAmplitude, DEFAULT_VIBRATION_SHARPNESS, false);
		});
		#end
	}
}
