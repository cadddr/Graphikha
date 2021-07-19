import kha.Framebuffer;
import Render;
import kha.Color;
import kha.Scheduler;
import pgr.dconsole.DC;

interface IRenderSampler {
    public function render(fb: Framebuffer): Void;
}

class SimpleRender implements IRenderSampler {
    private var renderer: Render;
    public function new(renderer: Render) {
        this.renderer = renderer;
    }

    public function render(fb: Framebuffer): Void {
        fb.g1.begin();
		for (y in 0...fb.height) {
			for (x in 0...fb.width) {
                var pixelColor: Color = renderer.getPixelColor(x, y, fb.width, fb.height);
                fb.g1.setPixel(x, y, pixelColor);
			}
		}
		fb.g1.end();
    }
}

class AdaptiveRender implements IRenderSampler {
    /*
currently: re-render everything on each frame (blocking)

goal: render must take a fixed amount of time (given by framerate target)
* vary resolution scale (reuse previously rendered pixels at lower resolution)
* vary number of AA samples (reuse previous samples)
* once rendered suspend rendering until render parameters change (e.g. camera move)
* or start over when done
*/

    private var renderer: Render;

    static var frameTime: Float;
    static var resolutionScale: Int = 2;

    static var callCount: Int = 0;
    static var backbuffer: Array<Array<Color>>;

    public function new(renderer: Render) {
        this.renderer = renderer;
        DC.monitorField(Main, "frameTime", "frameTime");
        DC.monitorField(Main, "resolutionScale", "resolutionScale");
        DC.monitorField(Main, "callCount", "callCount");
        DC.registerClass(Main, "AdaptiveRender");
    }

    public function render(fb: Framebuffer): Void {
		if (callCount == 0) {
			 backbuffer = [for (y in 0...fb.height) [for (x in 0...fb.width) 0xffffffff]];
		}
		var renderBeginTime = Scheduler.realTime();
		fb.g1.begin();
		// var bo = haxe.io.Bytes.alloc(WIDTH * HEIGHT);
		for (y in 0...fb.height) {
			for (x in 0...fb.width) {

				if (y % resolutionScale == 0) {
					if (x % resolutionScale == 0) {
						var x_ = x + callCount % resolutionScale;
						var y_ = y + Std.int(callCount / resolutionScale);
						DC.beginProfile("PixelTime");
						var pixelColor: Color = renderer.getPixelColor(x_, y_, fb.width, fb.height);
						backbuffer[y_][x_] = pixelColor;
						DC.endProfile("PixelTime");
					}
				}
				fb.g1.setPixel(x, y, backbuffer[y][x]);
				// bo.setInt32(backbuffer[y][x].value, x + y * WIDTH);
			}
		}
		fb.g1.end();
		var renderEndTime = Scheduler.realTime();
		frameTime = renderEndTime - renderBeginTime;

		callCount = (callCount + 1) % (resolutionScale * resolutionScale);

		// if (frameTime < REFRESH_RATE) {
		// 	resolutionScale = Std.int(Math.max(Std.int(resolutionScale / 2), 1));
		// }
		// else {
		// 	resolutionScale = Std.int(Math.min(Std.int(resolutionScale * 2), 600));
		// }

		
        
		
		// sys.io.File.saveBytes('output.txt', bo);
		
	}
}