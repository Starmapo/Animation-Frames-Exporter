package;

import animateatlas.AtlasFrameMaker;
import flash.display.PNGEncoderOptions;
import flash.geom.Point;
import flash.utils.ByteArray;
import flixel.FlxCamera;
import flixel.FlxG;
import flixel.FlxObject;
import flixel.FlxSprite;
import flixel.addons.display.FlxGridOverlay;
import flixel.addons.ui.FlxUI;
import flixel.addons.ui.FlxUICheckBox;
import flixel.addons.ui.FlxUIInputText;
import flixel.addons.ui.FlxUINumericStepper;
import flixel.addons.ui.FlxUIState;
import flixel.addons.ui.FlxUITabMenu;
import flixel.animation.FlxAnimation;
import flixel.graphics.frames.FlxAtlasFrames;
import flixel.graphics.frames.FlxFrame;
import flixel.graphics.frames.FlxFramesCollection;
import flixel.input.keyboard.FlxKey;
import flixel.math.FlxPoint;
import flixel.text.FlxText;
import flixel.ui.FlxButton;
import flixel.util.FlxColor;
import haxe.io.Path;
import lime.app.Application;
import openfl.display.BitmapData;
import openfl.geom.Matrix;
import openfl.geom.Rectangle;
import sys.FileSystem;
import sys.io.File;

using StringTools;

enum AtlasType {
	SPARROW; //Sparrow atlases, basically almost every single one (.png & .xmls)
    PACKER; //Sprite Sheet Packer atlases, like Spirit (.png & .txt)
    TEXTURE; //Adobe Animate texture atlases, like FNF HD (spritemap.png, spritemap.json, & Animation.json)
    PACKERJSON; //TexturePacker atlases, like NekoFreak (.png & .json)
}

typedef SpritesheetData = {
    var animations:Array<AnimData>;
    var flipX:Bool;
    var flipY:Bool;
    var noAntialiasing:Bool;
    var scale:Float;
    var angle:Float;
}

typedef AnimData = {
    var name:String;
}

/*
    NOTE:
    NOT ALL OF THIS CODE WAS THOUGHT OF BY ME
    I'M NOT THAT SMART
    HERE ARE THE THANKS THAT I HAVE REMEMBERED TO GIVE OUT
    https://github.com/ShadowMario/FNF-PsychEngine
    https://gist.github.com/miltoncandelero/0c452f832fa924bfdd60fe9d507bc581
    https://stackoverflow.com/questions/16273440/haxe-nme-resizing-a-bitmap
*/

class MainState extends FlxUIState {
    public static var muteKeys:Array<FlxKey> = [ZERO, NUMPADZERO];
    public static var volumeDownKeys:Array<FlxKey> = [MINUS, NUMPADMINUS];
    public static var volumeUpKeys:Array<FlxKey> = [PLUS, NUMPADPLUS];

    var daSprite:FlxSprite;
    var curSelected:Int = 0;
    var curAnimation:Int = 0;

    var gridBG:FlxSprite;
    public static var inputArray:Array<String> = [];
    public static var inputTypes:Map<String, AtlasType> = new Map<String, AtlasType>();
    var camEditor:FlxCamera;
	var camMenu:FlxCamera;
    var camHUD:FlxCamera;
    var camFollow:FlxPoint;
    var camFollowPos:FlxObject;
    var textAnim:FlxText;

    var UI_box:FlxUITabMenu;

    public static var textures:Map<String, FlxFramesCollection> = new Map<String, FlxFramesCollection>();
    public static var dataMap:Map<String, SpritesheetData> = new Map<String, SpritesheetData>();
    var currentData:SpritesheetData;

	private var blockPressWhileTypingOnStepper:Array<FlxUINumericStepper> = [];

    override function create()
    {
        getInputs(LoadingState.reloadAll);

        camEditor = new FlxCamera();
        camEditor.bgColor = FlxColor.BLACK;
        camHUD = new FlxCamera();
        camHUD.bgColor.alpha = 0;
        camMenu = new FlxCamera();
        camMenu.bgColor.alpha = 0;

        FlxG.cameras.reset(camEditor);
        FlxG.cameras.setDefaultDrawTarget(camEditor, true);
        FlxG.cameras.add(camHUD, false);
		FlxG.cameras.add(camMenu, false);

        camFollow = new FlxPoint(FlxG.width / 2, FlxG.height / 2);
		camFollowPos = new FlxObject(0, 0, 1, 1);
        add(camFollowPos);
        FlxG.camera.follow(camFollowPos, LOCKON, 1);
        FlxG.camera.focusOn(camFollow);
        FlxG.fixedTimestep = false;

        gridBG = FlxGridOverlay.create(40, 40, -1, -1, true, 0xff333333, 0xff262626);
        gridBG.scrollFactor.set();
        add(gridBG);

        var tipText:FlxText = new FlxText(FlxG.width - 20, FlxG.height, 0,
			"E/Q - Camera Zoom In/Out
            \nR - Reset Camera Zoom
			\nWASD - Move Camera
			\nUp/Down - Previous/Next Animation
			\nSpace - Pause/Play Animation
            \n,/. - Previous/Next Frame
			\nLeft/Right - Change Spritesheet
			\nHold Shift to Move 2x faster\n", 12);
		tipText.cameras = [camHUD];
		tipText.setFormat(null, 12, FlxColor.WHITE, CENTER, OUTLINE, FlxColor.BLACK);
		tipText.scrollFactor.set();
		tipText.borderSize = 1;
		tipText.x -= tipText.width;
		tipText.y -= tipText.height - 10;
		add(tipText);

        textAnim = new FlxText(300, 16, 0, '', 32);
		textAnim.setFormat(null, 32, FlxColor.WHITE, LEFT, OUTLINE, FlxColor.BLACK);
		textAnim.borderSize = 1;
		textAnim.scrollFactor.set();
		textAnim.cameras = [camHUD];
		add(textAnim);

        var tabs = [
			{name: 'Animation', label: 'Animation'},
            {name: 'Files', label: 'Files'}
		];
        UI_box = new FlxUITabMenu(null, tabs, true);
		UI_box.cameras = [camMenu];
		UI_box.resize(350, 250);
		UI_box.x = FlxG.width - 400;
		UI_box.y = 25;
		UI_box.scrollFactor.set();
		add(UI_box);

        addAnimationUI();
        addFilesUI();

        changeSelection();

        super.create();
    }

    var flipXCheckBox:FlxUICheckBox;
    var flipYCheckBox:FlxUICheckBox;
	var noAntialiasingCheckBox:FlxUICheckBox;
    var scaleStepper:FlxUINumericStepper;
    var angleStepper:FlxUINumericStepper;
    function addAnimationUI() {
        var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Animation";

        flipXCheckBox = new FlxUICheckBox(10, 25, null, null, "Flip X", 50);
		flipXCheckBox.callback = function() {
			daSprite.flipX = flipXCheckBox.checked;
            saveCurrentData();
		};

        flipYCheckBox = new FlxUICheckBox(flipXCheckBox.x + 70, 25, null, null, "Flip Y", 50);
		flipYCheckBox.callback = function() {
			daSprite.flipY = flipYCheckBox.checked;
            saveCurrentData();
		};

        noAntialiasingCheckBox = new FlxUICheckBox(flipYCheckBox.x + 70, 25, null, null, "No Antialiasing", 80);
		noAntialiasingCheckBox.callback = function() {
			daSprite.antialiasing = !noAntialiasingCheckBox.checked;
            saveCurrentData();
		};

        scaleStepper = new FlxUINumericStepper(noAntialiasingCheckBox.x + 130, 25, 0.1, 1, 0.05, 100, 2);
        blockPressWhileTypingOnStepper.push(scaleStepper);

        angleStepper = new FlxUINumericStepper(10, 65, 90, 0, 0, 360, 0);
        blockPressWhileTypingOnStepper.push(angleStepper);

        tab_group.add(new FlxText(scaleStepper.x, scaleStepper.y - 15, 0, 'Scale:'));
        tab_group.add(new FlxText(angleStepper.x, angleStepper.y - 15, 0, 'Angle:'));
        tab_group.add(flipXCheckBox);
        tab_group.add(flipYCheckBox);
		tab_group.add(noAntialiasingCheckBox);
        tab_group.add(scaleStepper);
        tab_group.add(angleStepper);
        UI_box.addGroup(tab_group);
    }

    function addFilesUI() {
        var tab_group = new FlxUI(null, UI_box);
		tab_group.name = "Files";

        var saveFrame:FlxButton = new FlxButton(10, 25, "Save Current Frame", function()
		{
            var file = '${inputArray[curSelected]}/${daSprite.frame.name}';
            if (FileSystem.exists('OUTPUT/$file.png')) {
                FileSystem.deleteFile('OUTPUT/$file.png');
            }
            saveBitmapFromFrame(daSprite.frame, file, getAnimRect(daSprite.animation.curAnim));
            if (FileSystem.exists('OUTPUT/$file.png')) {
                FlxG.sound.play('assets/sounds/confirmMenu.ogg');
            }
		});
        saveFrame.setGraphicSize(Std.int(saveFrame.width), Std.int(saveFrame.height * 2));
		changeAllLabelsOffset(saveFrame, 0, -6);

        var saveAnim:FlxButton = new FlxButton(saveFrame.x + 100, 25, "Save Current Animation", function()
        {
            var daAnim = daSprite.animation.curAnim;
            var checkName = '';
            for (frame in daAnim.frames) {
                var daFrame = daSprite.frames.frames[frame];
                saveBitmapFromFrame(daFrame, '${inputArray[curSelected]}/${daFrame.name}', getAnimRect(daAnim));
                if (checkName.length < 1) {
                    checkName = daFrame.name;
                }
            }
            if (FileSystem.exists('OUTPUT/${inputArray[curSelected]}/$checkName.png')) {
                FlxG.sound.play('assets/sounds/confirmMenu.ogg');
            }
        });
        saveAnim.setGraphicSize(Std.int(saveAnim.width), Std.int(saveAnim.height * 2));
        changeAllLabelsOffset(saveAnim, 0, -6);

        var saveAllFrames:FlxButton = new FlxButton(saveAnim.x + 100, 25, "Save All Frames", function()
        {
            var folder = 'OUTPUT/${inputArray[curSelected]}';
            if (FileSystem.exists(folder) && FileSystem.isDirectory(folder)) {
                for (i in FileSystem.readDirectory(folder)) {
                    var path = Path.join([folder, i]);
                    if (!FileSystem.isDirectory(path)) {
                        FileSystem.deleteFile(path);
                    }
                }
            }
            for (i in daSprite.animation.getAnimationList()) {
                for (frame in i.frames) {
                    var daFrame = daSprite.frames.frames[frame];
                    saveBitmapFromFrame(daFrame, '${inputArray[curSelected]}/${daFrame.name}', getAnimRect(i));
                }
            }
            if (FileSystem.exists(folder) && FileSystem.isDirectory(folder) && FileSystem.readDirectory(folder).length > 0) {
                FlxG.sound.play('assets/sounds/confirmMenu.ogg');
            }
        });
        saveAllFrames.setGraphicSize(Std.int(saveAllFrames.width), Std.int(saveAllFrames.height * 2));
		changeAllLabelsOffset(saveAllFrames, 0, -6);

        var updateSpritesheets:FlxButton = new FlxButton(10, saveFrame.y + 50, "Reload Spritesheets", function()
		{
            FlxG.switchState(new LoadingState(true));
		});
        updateSpritesheets.setGraphicSize(Std.int(updateSpritesheets.width), Std.int(updateSpritesheets.height * 2));
		changeAllLabelsOffset(updateSpritesheets, 0, -6);

        tab_group.add(saveFrame);
        tab_group.add(saveAnim);
        tab_group.add(saveAllFrames);
        tab_group.add(updateSpritesheets);
        UI_box.addGroup(tab_group);
    }

    override public function update(elapsed:Float) {
        super.update(elapsed);

        daSprite.screenCenter();

        if (angleStepper.value % 90 != 0) {
            angleStepper.value = 90 * Math.round(angleStepper.value / 90);
            getEvent(FlxUINumericStepper.CHANGE_EVENT, angleStepper, null);
        }
        
        var blockInput:Bool = false;
        for (stepper in blockPressWhileTypingOnStepper) {
            @:privateAccess
            var leText:Dynamic = stepper.text_field;
            var leText:FlxUIInputText = leText;
            if (leText.hasFocus) {
                FlxG.sound.muteKeys = [];
                FlxG.sound.volumeDownKeys = [];
                FlxG.sound.volumeUpKeys = [];
                blockInput = true;
                break;
            }
        }

		if (!blockInput) {
			FlxG.sound.muteKeys = muteKeys;
			FlxG.sound.volumeDownKeys = volumeDownKeys;
			FlxG.sound.volumeUpKeys = volumeUpKeys;
		}

        if (!blockInput) {
            var controlArray = [FlxG.keys.justPressed.LEFT, FlxG.keys.justPressed.RIGHT];
                    
            for (i in 0...controlArray.length) {
                if (controlArray[i]) {
                    var negaMult = -1;
                    if (i % 2 == 1) negaMult = 1;
                    changeSelection(negaMult);
                    FlxG.sound.play('assets/sounds/scrollMenu.ogg');
                }
            }

            if (FlxG.keys.pressed.Q && FlxG.camera.zoom > 0.1) {
                FlxG.camera.zoom -= elapsed * 3;
                if (FlxG.camera.zoom < 0.1) FlxG.camera.zoom = 0.1;
            }
            if (FlxG.keys.pressed.E && FlxG.camera.zoom < 3) {
                FlxG.camera.zoom += elapsed * 3;
                if (FlxG.camera.zoom > 3) FlxG.camera.zoom = 3;
            }
            if (FlxG.keys.pressed.R) {
                FlxG.camera.zoom = 1;
            }

            if (daSprite.animation.curAnim != null) {
                if (FlxG.keys.justPressed.SPACE) {
                    if (daSprite.animation.finished) {
                        daSprite.animation.play(daSprite.animation.name, true);
                    } else if (daSprite.animation.paused) {
                        daSprite.animation.resume();
                    } else {
                        daSprite.animation.pause();
                    }
                }
                if (daSprite.animation.curAnim.numFrames > 1) {
                    if (FlxG.keys.justPressed.COMMA) {
                        daSprite.animation.pause();
                        if (daSprite.animation.curAnim.curFrame <= 0) {
                            daSprite.animation.curAnim.curFrame = daSprite.animation.curAnim.numFrames - 1;
                        } else {
                            --daSprite.animation.curAnim.curFrame;
                        }
                    }
                    if (FlxG.keys.justPressed.PERIOD) {
                        daSprite.animation.pause();
                        if (daSprite.animation.curAnim.curFrame >= daSprite.animation.curAnim.numFrames - 1) {
                            daSprite.animation.curAnim.curFrame = 0;
                        } else {
                            daSprite.animation.curAnim.curFrame++;
                        }
                    }
                }
                if (currentData.animations.length > 1) {
                    if (FlxG.keys.justPressed.UP) {
                        --curAnimation;
                        if (curAnimation < 0) {
                            curAnimation = currentData.animations.length - 1;
                        }
                        daSprite.animation.play(currentData.animations[curAnimation].name, true);
                    } else if (FlxG.keys.justPressed.DOWN) {
                        curAnimation++;
                        if (curAnimation > currentData.animations.length - 1) {
                            curAnimation = 0;
                        }
                        daSprite.animation.play(currentData.animations[curAnimation].name, true);
                    }
                }
                textAnim.text = '${inputArray[curSelected]}\n${daSprite.animation.name}\n${daSprite.animation.curAnim.curFrame + 1}/${daSprite.animation.curAnim.numFrames}';
            } else {
                textAnim.text = '';
            }

            var controlArray = [FlxG.keys.pressed.A, FlxG.keys.pressed.D, FlxG.keys.pressed.W, FlxG.keys.pressed.S];
                    
            for (i in 0...controlArray.length) {
                if (controlArray[i]) {
                    var holdShift = FlxG.keys.pressed.SHIFT;
                    var multiplier = elapsed * 600;
                    if (holdShift)
                        multiplier = elapsed * 1200;

                    var negaMult = -1;
                    if (i % 2 == 1) negaMult = 1;
                    if (i > 1) {
                        camFollow.y += negaMult * multiplier;
                    } else {
                        camFollow.x += negaMult * multiplier;
                    }
                }
            }

            camFollowPos.setPosition(camFollow.x, camFollow.y);
        }
    }

    function changeSelection(add:Int = 0) {
        curSelected += add;
        if (curSelected < 0) {
            curSelected = inputArray.length - 1;
        } else if (curSelected > inputArray.length - 1) {
            curSelected = 0;
        }

        makeSprite();
    }

    function getInputs(reloadAll:Bool = false) {
        inputArray = [];
        inputTypes.clear();
        textures.clear();
        var folder:String = 'INPUT';
        if (FileSystem.exists(folder)) {
            for (file in FileSystem.readDirectory(folder)) {
                var path = Path.join([folder, file]);
                if (file.endsWith('.png') && !inputArray.contains(file)) {
                    //trace('file: $file');
                    var rawName = file.substr(0, file.length - 4);
                    inputArray.push(rawName);
                    if (FileSystem.exists('$folder/$rawName.txt')) {
                        inputTypes.set(rawName, PACKER);
                    } else if (FileSystem.exists('$folder/$rawName.json')) {
                        inputTypes.set(rawName, PACKERJSON);
                    } else {
                        inputTypes.set(rawName, SPARROW);
                    }
                } else if (FileSystem.isDirectory(path) && FileSystem.exists(path + '/Animation.json')) {
                    //trace('texture atlas: $file');
                    inputArray.push(file);
                    inputTypes.set(file, TEXTURE);
                }
            }
            preloadTextures(reloadAll);
            //trace('Gotten inputs: $inputArray');
            //trace('Gotten types: $inputTypes');
        } else {
            Application.current.window.alert('"INPUT" folder doesn\'t exist!', 'Error');
        }
        if (!FileSystem.exists('OUTPUT/')) {
            Application.current.window.alert('"OUTPUT" folder doesn\'t exist!', 'Error');
        }
    }

    function makeSprite() {
        if (members.contains(daSprite))
            remove(daSprite, true);

        if (dataMap.exists(inputArray[curSelected])) {
            currentData = dataMap.get(inputArray[curSelected]);
            loadCurrentData();
        }

        daSprite = new FlxSprite();
        reloadSpriteImage();
        daSprite.screenCenter();

        curAnimation = 0;
        daSprite.flipX = flipXCheckBox.checked;
        daSprite.flipY = flipYCheckBox.checked;
        daSprite.antialiasing = !noAntialiasingCheckBox.checked;

        add(daSprite);
    }

    function preloadTextures(reloadAll:Bool = false) {
        if (reloadAll) {
            textures.clear();
        } else {
            for (i in textures.keys()) {
                if (!inputArray.contains(i)) {
                    textures.remove(i);
                }
            }
        }
        for (i in inputArray) {
            switch (inputTypes.get(i)) {
                case SPARROW:
                    var bitmap:BitmapData = BitmapData.fromFile('INPUT/$i.png');
                    var xml:String = File.getContent('INPUT/$i.xml');
                    var daFrames = FlxAtlasFrames.fromSparrow(bitmap, xml);
                    textures.set(i, daFrames);
                case PACKER:
                    var bitmap:BitmapData = BitmapData.fromFile('INPUT/$i.png');
                    var txt:String = File.getContent('INPUT/$i.txt');
                    var daFrames = FlxAtlasFrames.fromSpriteSheetPacker(bitmap, txt);
                    textures.set(i, daFrames);
                case TEXTURE:
                    var daFrames = AtlasFrameMaker.construct('INPUT/$i');
                    textures.set(i, daFrames);
                case PACKERJSON:
                    var bitmap:BitmapData = BitmapData.fromFile('INPUT/$i.png');
                    var json:String = File.getContent('INPUT/$i.json');
                    var daFrames = FlxAtlasFrames.fromTexturePackerJson(bitmap, json);
                    textures.set(i, daFrames);
            }
        }
    }

    function reloadSpriteImage() {
        var curInput = inputArray[curSelected];
        switch (inputTypes.get(curInput)) {
            case SPARROW:
                if (textures.exists(curInput)) {
                    daSprite.frames = textures.get(curInput);
                } else {
                    trace('HAVING TO MAKE $curInput');
                    var bitmap:BitmapData = BitmapData.fromFile('INPUT/$curInput.png');
                    var xml:String = File.getContent('INPUT/$curInput.xml');
                    daSprite.frames = FlxAtlasFrames.fromSparrow(bitmap, xml);
                    textures.set(curInput, daSprite.frames);
                }
            case PACKER:
                if (textures.exists(curInput)) {
                    daSprite.frames = textures.get(curInput);
                } else {
                    trace('HAVING TO MAKE $curInput');
                    var bitmap:BitmapData = BitmapData.fromFile('INPUT/$curInput.png');
                    var txt:String = File.getContent('INPUT/$curInput.txt');
                    daSprite.frames = FlxAtlasFrames.fromSpriteSheetPacker(bitmap, txt);
                    textures.set(curInput, daSprite.frames);
                }
            case TEXTURE:
                if (textures.exists(curInput)) {
                    daSprite.frames = textures.get(curInput);
                } else { //should already be preloaded but just in case
                    trace('HAVING TO MAKE $curInput');
                    daSprite.frames = AtlasFrameMaker.construct('INPUT/$curInput');
                    textures.set(curInput, daSprite.frames);
                }
            case PACKERJSON:
                if (textures.exists(curInput)) {
                    daSprite.frames = textures.get(curInput);
                } else {
                    trace('HAVING TO MAKE $curInput');
                    var bitmap:BitmapData = BitmapData.fromFile('INPUT/$curInput.png');
                    var json:String = File.getContent('INPUT/$curInput.json');
                    daSprite.frames = FlxAtlasFrames.fromTexturePackerJson(bitmap, json);
                    textures.set(curInput, daSprite.frames);
                }
        }

        if (dataMap.exists(curInput)) {
            var data = dataMap.get(curInput);
            for (i in data.animations) {
                switch inputTypes.get(curInput) {
                    case SPARROW:
                        daSprite.animation.addByPrefix(i.name, '${i.name}0', 24, false);
                    case PACKER:
                        daSprite.animation.addByPrefix(i.name, '${i.name}_', 24, false);
                    case TEXTURE:
                        daSprite.animation.addByPrefix(i.name, i.name, 24, false);
                    case PACKERJSON:
                        daSprite.animation.addByPrefix(i.name, '${i.name} instance ', 24, false);
                }
                if (daSprite.animation.curAnim == null) {
                    daSprite.animation.play(i.name);
                }
            }
        } else if (inputTypes.get(curInput) == TEXTURE) {
            var newData:SpritesheetData = {
                animations: [],
                flipX: false,
                flipY: false,
                noAntialiasing: false,
                scale: 1,
                angle: 0
            };
            for (i in AtlasFrameMaker.getFrameLabels('INPUT/$curInput')) {
                daSprite.animation.addByPrefix(i, i, false);
                if (daSprite.animation.curAnim == null) {
                    daSprite.animation.play(i);
                }
                newData.animations.push({
                    name: i
                });
            }
            dataMap.set(curInput, newData);
        } else {
            var stupidAnims:Array<String> = [];
            var newData:SpritesheetData = {
                animations: [],
                flipX: false,
                flipY: false,
                noAntialiasing: false,
                scale: 1,
                angle: 0
            };
            for (i in daSprite.frames.frames) {
                if (i != null) {
                    switch (inputTypes.get(curInput)) {
                        case SPARROW:
                            var daName = i.name.substr(0, i.name.length - 4);
                            if (!stupidAnims.contains(daName)) {
                                daSprite.animation.addByPrefix(daName, '${daName}0', 24, false);
                                if (daSprite.animation.curAnim == null) {
                                    daSprite.animation.play(daName);
                                }
                                newData.animations.push({
                                    name: daName
                                });
                                stupidAnims.push(daName);
                            }
                        case PACKER:
                            var daName = i.name.substr(0, i.name.lastIndexOf('_'));
                            if (!stupidAnims.contains(daName)) {
                                daSprite.animation.addByPrefix(daName, '${daName}_', 24, false);
                                if (daSprite.animation.curAnim == null) {
                                    daSprite.animation.play(daName);
                                }
                                newData.animations.push({
                                    name: daName
                                });
                                stupidAnims.push(daName);
                            }
                        case TEXTURE:
                        case PACKERJSON:
                            var daName = i.name.substr(0, i.name.lastIndexOf('instance ') - 1);
                            if (!stupidAnims.contains(daName)) {
                                daSprite.animation.addByPrefix(daName, daName, 24, false);
                                if (daSprite.animation.curAnim == null) {
                                    daSprite.animation.play(daName);
                                }
                                newData.animations.push({
                                    name: daName
                                });
                                stupidAnims.push(daName);
                            }
                    }
                }
            }
            dataMap.set(curInput, newData);
        }
        currentData = dataMap.get(curInput);
        loadCurrentData();
        daSprite.setGraphicSize(Std.int(daSprite.width * scaleStepper.value));
        daSprite.updateHitbox();
        daSprite.angle = angleStepper.value;
    }

    function saveBitmapFromFrame(frame:FlxFrame, file:String, rect:Rectangle) {
        var flipX = flipXCheckBox.checked;
        var flipY = flipYCheckBox.checked;
        var angle = FlxFrameAngle.ANGLE_0;
        switch (angleStepper.value) {
            case 90:
                angle = FlxFrameAngle.ANGLE_90;
                var old = flipY;
                flipY = flipX;
                flipX = old;
            case 180:
                flipX = !flipX;
                flipY = !flipY;
            case 270:
                angle = FlxFrameAngle.ANGLE_NEG_90;
                var old = flipX;
                flipX = flipY;
                flipY = old;
        }
        if (inputTypes.get(inputArray[curSelected]) != TEXTURE) {
            var bitmap:BitmapData = new BitmapData(Std.int(rect.width), Std.int(rect.height), true, 0);
            if (angle == FlxFrameAngle.ANGLE_90 || angle == FlxFrameAngle.ANGLE_NEG_90) {
                bitmap = new BitmapData(Std.int(rect.height), Std.int(rect.width), true, 0);
            }
            frame.paintRotatedAndFlipped(bitmap, null, angle, flipX, flipY);
            var newWidth = Std.int(bitmap.width * scaleStepper.value);
            var newHeight = Std.int(bitmap.height * scaleStepper.value);
            var newBitmap = new BitmapData(newWidth, newHeight, true, 0);
            var matrix = new Matrix();
            matrix.scale(scaleStepper.value, scaleStepper.value);
            newBitmap.draw(bitmap, matrix, null, null, null, !noAntialiasingCheckBox.checked);
            saveImage(newBitmap, file, newBitmap.rect);
        } else {
            var bitmap:BitmapData = new BitmapData(Std.int(rect.width), Std.int(rect.height), true, 0);
            frame.paint(bitmap);
            var newWidth = Std.int(bitmap.width * scaleStepper.value);
            var newHeight = Std.int(bitmap.height * scaleStepper.value);
            if (angle == FlxFrameAngle.ANGLE_90 || angle == FlxFrameAngle.ANGLE_NEG_90) {
                var old = newWidth;
                newWidth = newHeight;
                newHeight = old;
            }
            var newBitmap = new BitmapData(newWidth, newHeight, true, 0);
            var matrix = new Matrix();
            //THIS IS TAKEN FROM FLXFRAME & FLXMATRIX
            @:privateAccess{
            matrix.a = frame.blitMatrix[0];
            matrix.b = frame.blitMatrix[1];
            matrix.c = frame.blitMatrix[2];
            matrix.d = frame.blitMatrix[3];
            matrix.tx = frame.blitMatrix[4];
            matrix.ty = frame.blitMatrix[5];
            }
            matrix.scale(scaleStepper.value, scaleStepper.value);
            if (angle == FlxFrameAngle.ANGLE_90) {
                matrix.setTo(-matrix.b, matrix.a, -matrix.d, matrix.c, -matrix.ty, matrix.tx);
                matrix.translate(newWidth, 0);
            } else if (angle == FlxFrameAngle.ANGLE_NEG_90) {
                matrix.setTo(matrix.b, -matrix.a, matrix.d, -matrix.c, matrix.ty, -matrix.tx);
                matrix.translate(0, newHeight);
            }
            if (flipX) {
                matrix.scale(-1, 1);
                matrix.translate(newWidth, 0);
            }
            if (flipY) {
                matrix.scale(1, -1);
                matrix.translate(0, newHeight);
            }
            newBitmap.draw(bitmap, matrix, null, null, null, !noAntialiasingCheckBox.checked);
            saveImage(newBitmap, file, newBitmap.rect);
        }
    }

    function saveImage(bitmap:BitmapData, file:String, rect:Rectangle) {
        var b:ByteArray = new ByteArray();
        b = bitmap.encode(rect, new PNGEncoderOptions(true), b);
        if (!FileSystem.exists('OUTPUT/${file.substr(0, file.lastIndexOf('/'))}')) {
            FileSystem.createDirectory('OUTPUT/${file.substr(0, file.lastIndexOf('/'))}');
        }
        File.saveBytes('OUTPUT/$file.png', b);
    }

    override function getEvent(id:String, sender:Dynamic, data:Dynamic, ?params:Array<Dynamic>) {
		if (id == FlxUIInputText.CHANGE_EVENT && (sender is FlxUIInputText)) {
			
		} else if (id == FlxUINumericStepper.CHANGE_EVENT && (sender is FlxUINumericStepper)) {
			if (sender == scaleStepper || sender == angleStepper) {
                var lastAnim = daSprite.animation.name;
                saveCurrentData();
                reloadSpriteImage();
                daSprite.animation.play(lastAnim, true);
            }
		}
	}

    function changeAllLabelsOffset(button:FlxButton, x:Float, y:Float)
	{
		for (point in button.labelOffsets)
		{
			point.set(point.x + x, point.y + y);
		}
	}

    function getAnimRect(anim:FlxAnimation):Rectangle {
        /*if (inputTypes.get(inputArray[curSelected]) != TEXTURE) {
            return null;
        }*/
        //IF I DONT DO THIS TEXTURE ATLASES AREN'T CROPPED PROPERLY???
        var maxWidth:Float = 1;
        var maxHeight:Float = 1;
        for (i in anim.frames) {
            var frame = daSprite.frames.frames[i];
            if (frame.frame.width + frame.offset.x > maxWidth) {
                maxWidth = frame.frame.width + frame.offset.x;
            }
            if (frame.frame.height + frame.offset.y > maxHeight) {
                maxHeight = frame.frame.height + frame.offset.y;
            }
        }
        return new Rectangle(0, 0, maxWidth, maxHeight);
    }

    function saveCurrentData() {
        currentData.flipX = flipXCheckBox.checked;
        currentData.flipY = flipYCheckBox.checked;
        currentData.noAntialiasing = noAntialiasingCheckBox.checked;
        currentData.scale = scaleStepper.value;
        currentData.angle = angleStepper.value;

        dataMap.set(inputArray[curSelected], currentData);
    }

    function loadCurrentData() {
        flipXCheckBox.checked = currentData.flipX;
        flipYCheckBox.checked = currentData.flipY;
        noAntialiasingCheckBox.checked = currentData.noAntialiasing;
        scaleStepper.value = currentData.scale;
        angleStepper.value = currentData.angle;
    }
}