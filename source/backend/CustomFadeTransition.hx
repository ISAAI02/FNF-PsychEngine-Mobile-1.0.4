package backend;

import flixel.util.FlxGradient;
import flixel.FlxSubState;

class CustomFadeTransition extends FlxSubState {
	public static var finishCallback:Void->Void;
	public var finishCallbackInstance:Void->Void = null;
	var isTransIn:Bool = false;
	var transBlack:FlxSprite;
	var transGradient:FlxSprite;

	var duration:Float;
	public function new(duration:Float, isTransIn:Bool)
	{
		this.duration = duration;
		this.isTransIn = isTransIn;
		super();
	}

	override function create()
	{
		var cam:FlxCamera = (FlxG.cameras.list.length > 0) ? FlxG.cameras.list[FlxG.cameras.list.length - 1] : FlxG.camera;
		if (cam != null)
		{
			cam.visible = true;
			cameras = [cam];
		}
		var camZoom:Float = (camera != null) ? Math.max(camera.zoom, 0.001) : 1.0;
		var width:Int = Std.int(FlxG.width / camZoom);
		var height:Int = Std.int(FlxG.height / camZoom);
		transGradient = FlxGradient.createGradientFlxSprite(1, height, (isTransIn ? [0x0, FlxColor.BLACK] : [FlxColor.BLACK, 0x0]));
		transGradient.scale.x = width;
		transGradient.updateHitbox();
		transGradient.scrollFactor.set();
		transGradient.screenCenter(X);
		add(transGradient);

		transBlack = new FlxSprite().makeGraphic(1, 1, FlxColor.BLACK);
		transBlack.scale.set(width, height + 400);
		transBlack.updateHitbox();
		transBlack.scrollFactor.set();
		transBlack.screenCenter(X);
		add(transBlack);

		if(isTransIn)
			transGradient.y = transBlack.y - transBlack.height;
		else
			transGradient.y = -transGradient.height;

		super.create();
	}

	override function update(elapsed:Float) {
		super.update(elapsed);

		final dt:Float = FlxMath.bound(elapsed, 0.0, 0.1);
		final camZoom:Float = (camera != null) ? Math.max(camera.zoom, 0.001) : 1.0;
		final height:Float = FlxG.height * camZoom;
		final targetPos:Float = transGradient.height + 50 * camZoom;
		if(duration > 0)
			transGradient.y += (height + targetPos) * dt / duration;
		else
			transGradient.y = targetPos;

		if(isTransIn)
			transBlack.y = transGradient.y + transGradient.height;
		else
			transBlack.y = transGradient.y - transBlack.height;

		if(transGradient.y >= targetPos)
		{
			close();
		}
	}

	// Don't delete this
	override function close():Void
	{
		super.close();

		var cb:Void->Void = (finishCallbackInstance != null) ? finishCallbackInstance : finishCallback;
		if (finishCallback == finishCallbackInstance)
			finishCallback = null;
		finishCallbackInstance = null;

		if(cb != null)
		{
			cb();
		}
	}
}
