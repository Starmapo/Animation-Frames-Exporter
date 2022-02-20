package;

import flixel.FlxG;
import flixel.FlxSprite;
import flixel.addons.ui.FlxUIState;
import flixel.text.FlxText;
import flixel.util.FlxColor;
import flixel.util.FlxTimer;

using StringTools;

class LoadingState extends FlxUIState {
    public static var reloadAll:Bool = false;

    public function new(reloadAll:Bool = false) {
        LoadingState.reloadAll = reloadAll;
        super();
    }

    override function create() {
        var bg = new FlxSprite().makeGraphic(FlxG.width, FlxG.height, FlxColor.BLACK);
        add(bg);

        var loadText = new FlxText(0, 0, FlxG.width, 'Loading...', 32);
        loadText.setFormat("assets/fonts/vcr.ttf", 32, FlxColor.WHITE, CENTER);
        loadText.screenCenter();
        add(loadText);

        new FlxTimer().start(0.5, function(tmr:FlxTimer) {
            FlxG.switchState(new MainState());
        });

        super.create();
    }
}