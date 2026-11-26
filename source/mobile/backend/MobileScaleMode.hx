/*
 * Copyright (C) 2025 Mobile Porting Team
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

package mobile.backend;

import flixel.system.scaleModes.BaseScaleMode;

/**
 * ...
 * @author: Karim Akra
 */
class MobileScaleMode extends BaseScaleMode
{
	public static var allowWideScreen(default, set):Bool = true;
	private static var borderMask:openfl.display.Shape;

	override function updateGameSize(Width:Int, Height:Int):Void
	{
		if (ClientPrefs.data.wideScreen && allowWideScreen)
		{
			super.updateGameSize(Width, Height);
		}
		else
		{
			var ratio:Float = FlxG.width / FlxG.height;
			var realRatio:Float = Width / Height;

			var scaleY:Bool = realRatio < ratio;

			if (scaleY)
			{
				// Round to multiple of 10 so scaleX = gameSize.x / 1280 has an exact power-of-two float denominator,
				// preventing 1px glScissor bleed on the right/bottom viewport edge in OpenGL ES.
				gameSize.x = Width - (Width % 10);
				gameSize.y = Math.round(gameSize.x / ratio);
				gameSize.y -= (gameSize.y % 2);
			}
			else
			{
				var rawWidth:Int = Math.floor(Height * ratio);
				gameSize.x = rawWidth - (rawWidth % 10);
				gameSize.y = Math.min(Height, Math.round(gameSize.x / ratio));
			}
		}
	}

	override function updateGamePosition():Void
	{
		if (ClientPrefs.data.wideScreen && allowWideScreen)
		{
			FlxG.game.x = FlxG.game.y = 0;
		}
		else
		{
			super.updateGamePosition();
			FlxG.game.x = Math.floor(FlxG.game.x);
			FlxG.game.y = Math.floor(FlxG.game.y);
		}
		updateBorderMask();
	}

	private function updateBorderMask():Void
	{
		if (FlxG.stage == null || FlxG.game == null)
			return;

		if (borderMask == null)
			borderMask = new openfl.display.Shape();

		if (borderMask.parent != FlxG.stage)
		{
			var gameIdx:Int = FlxG.stage.getChildIndex(FlxG.game);
			if (gameIdx >= 0)
				FlxG.stage.addChildAt(borderMask, gameIdx + 1);
			else
				FlxG.stage.addChild(borderMask);
		}

		borderMask.graphics.clear();
		if (ClientPrefs.data.wideScreen && allowWideScreen)
			return;

		var stageW:Float = FlxG.stage.stageWidth;
		var stageH:Float = FlxG.stage.stageHeight;
		var gx:Float = FlxG.game.x;
		var gy:Float = FlxG.game.y;
		var gw:Float = gameSize.x;
		var gh:Float = gameSize.y;

		borderMask.graphics.beginFill(0x000000, 1.0);
		if (gx > 0)
			borderMask.graphics.drawRect(0, 0, gx + 2, stageH);
		if (gx + gw < stageW)
			borderMask.graphics.drawRect(gx + gw - 2, 0, (stageW - (gx + gw)) + 4, stageH);
		if (gy > 0)
			borderMask.graphics.drawRect(0, 0, stageW, gy + 2);
		if (gy + gh < stageH)
			borderMask.graphics.drawRect(0, gy + gh - 2, stageW, (stageH - (gy + gh)) + 4);
		borderMask.graphics.endFill();
	}

	@:noCompletion
	private static function set_allowWideScreen(value:Bool):Bool
	{
		allowWideScreen = value;
		FlxG.scaleMode = new MobileScaleMode();
		return value;
	}
}
