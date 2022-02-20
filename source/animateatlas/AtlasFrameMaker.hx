package animateatlas;

import openfl.geom.Rectangle;
import flixel.math.FlxPoint;
import flixel.math.FlxRect;
import haxe.Json;
import openfl.display.BitmapData;
import animateatlas.JSONData.AtlasData;
import animateatlas.JSONData.AnimationData;
import animateatlas.displayobject.SpriteAnimationLibrary;
import animateatlas.displayobject.SpriteMovieClip;
import flixel.graphics.FlxGraphic;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.graphics.frames.FlxFrame;
import sys.FileSystem;
import sys.io.File;

using StringTools;
class AtlasFrameMaker extends FlxFramesCollection
{
	/**

	* Creates Frames from TextureAtlas | Originally made for FNF HD by Smokey and Rozebud
	*
	* @param   key                 The file path.
	* @param   _excludeArray       Use this to only create selected animations. Keep null to create all of them.
	*
	*/

	public static function construct(key:String,?_excludeArray:Array<String> = null):FlxFramesCollection
	{
		var frameCollection:FlxFramesCollection;
		var frameArray:Array<Array<FlxFrame>> = [];

		if (FileSystem.exists('$key/spritemap1.json'))
		{
			trace('$key: Only Spritemaps made with Adobe Animate 2018 are supported');
			return null;
		}

		var animationData:AnimationData = Json.parse(File.getContent('$key/Animation.json'));
		var atlasData:AtlasData = Json.parse(File.getContent('$key/spritemap.json').replace("\uFEFF", ""));

		var bitmap = BitmapData.fromFile('$key/spritemap.png');
		var graphic = FlxGraphic.fromBitmapData(bitmap);
		var ss = new SpriteAnimationLibrary(animationData, atlasData, bitmap);
		var t = ss.createAnimation();
		if (_excludeArray == null)
		{
			_excludeArray = t.getFrameLabels();
		}
		//trace('Creating: $_excludeArray');

		frameCollection = new FlxFramesCollection(graphic, IMAGE);
		for(x in _excludeArray)
		{
			frameArray.push(getFramesArray(t, x));
		}

		for(x in frameArray)
		{
			for(y in x)
			{
				frameCollection.pushFrame(y);
			}
		}
		return frameCollection;
	}

	@:noCompletion static function getFramesArray(t:SpriteMovieClip,animation:String):Array<FlxFrame>
	{
		var sizeInfo = new Rectangle(0, 0);
		t.currentLabel = animation;
		var bitMapArray:Array<BitmapData> = [];
		var daFramez:Array<FlxFrame> = [];
		var firstPass = true;
		var frameSize = new FlxPoint(0, 0);

		for (i in t.getFrame(animation)...t.numFrames)
		{
			t.currentFrame = i;
			if (t.currentLabel == animation)
			{
				sizeInfo = t.getBounds(t);
				var bitmapShit = new BitmapData(Std.int(sizeInfo.width + sizeInfo.x), Std.int(sizeInfo.height + sizeInfo.y), true, 0);
				bitmapShit.draw(t, null, null, null, null, true);
				bitMapArray.push(bitmapShit);

				if (firstPass)
				{
					frameSize.set(bitmapShit.width, bitmapShit.height);
					firstPass = false;
				}
			}
			else break;
		}

		for (i in 0...bitMapArray.length)
		{
			var b = FlxGraphic.fromBitmapData(bitMapArray[i]);
			var theFrame = new FlxFrame(b);
			theFrame.parent = b;
			theFrame.name = animation + '$' + i;
			theFrame.sourceSize.set(frameSize.x,frameSize.y);
			theFrame.frame = new FlxRect(0, 0, bitMapArray[i].width, bitMapArray[i].height);
			daFramez.push(theFrame);
		}
		return daFramez;
	}

	public static function getFrameLabels(key:String):Array<String> {
		if (FileSystem.exists('$key/spritemap1.json'))
		{
			trace('$key: Only Spritemaps made with Adobe Animate 2018 are supported');
			return null;
		}

		var animationData:AnimationData = Json.parse(File.getContent('$key/Animation.json'));
		var atlasData:AtlasData = Json.parse(File.getContent('$key/spritemap.json').replace("\uFEFF", ""));

		var bitmap = BitmapData.fromFile('$key/spritemap.png');
		var graphic = FlxGraphic.fromBitmapData(bitmap);
		var ss = new SpriteAnimationLibrary(animationData, atlasData, graphic.bitmap);
		var t = ss.createAnimation();
		return t.getFrameLabels();
	}
}